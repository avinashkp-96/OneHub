import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

// docx 4.2 "Search". A keyword is matched, case-insensitively, against
// provider names, service names and category names. Results come back in two
// lists: matching services (which lead straight to posting a request) and
// matching active providers.
//
// Filters: category, minimum rating and maximum starting price. Providers set
// no prices up front, so a provider's "starting price" is the lowest suggested
// price among the services they offer that match. Sort: highest rated (the
// default) or lowest price.
//
// Not supported yet: nearest first and the distance filter (provider
// locations are not captured at signup), and "available now" (online status
// is not saved). Filtering happens in memory over active providers, which is
// fine for the MVP's size; move it into the query when the catalogue grows.
export interface SearchQuery {
  q?: string;
  categoryId?: string;
  minRating?: number;
  maxPrice?: number;
  sort?: 'rating' | 'price';
}

type Service = {
  id: string;
  name: string;
  suggestedMinPrice: number | null;
  suggestedMaxPrice: number | null;
  category: { id: string; name: string; active: boolean };
};

const SERVICE_SELECT = {
  id: true,
  name: true,
  suggestedMinPrice: true,
  suggestedMaxPrice: true,
  category: { select: { id: true, name: true, active: true } },
} as const;

@Injectable()
export class SearchService {
  constructor(private readonly prisma: PrismaService) {}

  async search(query: SearchQuery) {
    const words = normalise(query.q);
    const sort = query.sort === 'price' ? 'price' : 'rating';

    const services = (await this.prisma.subService.findMany({ select: SERVICE_SELECT })) as Service[];
    const serviceMatches = (s: Service) =>
      s.category.active &&
      (!query.categoryId || s.category.id === query.categoryId) &&
      (query.maxPrice === undefined || (s.suggestedMinPrice ?? 0) <= query.maxPrice) &&
      matchesAll(words, `${s.name} ${s.category.name}`);

    const providers = await this.prisma.provider.findMany({
      where: { status: 'ACTIVE', averageRating: { gte: query.minRating ?? 0 } },
      select: {
        id: true,
        businessName: true,
        yearsExperience: true,
        averageRating: true,
        ratingCount: true,
        certified: true,
        user: { select: { fullName: true } },
        subServices: { select: { subService: { select: SERVICE_SELECT } } },
      },
    });

    const providerResults = providers
      .map((p) => {
        const name = p.businessName ?? p.user.fullName;
        const offered = (p.subServices.map((s) => s.subService) as Service[]).filter(
          (s) => s.category.active && (!query.categoryId || s.category.id === query.categoryId),
        );
        // A keyword that matches the provider's name keeps all their services;
        // otherwise only the services that match it count.
        const relevant = matchesAll(words, name) ? offered : offered.filter((s) => matchesAll(words, `${s.name} ${s.category.name}`));
        const prices = relevant.map((s) => s.suggestedMinPrice).filter((v): v is number => v !== null);
        return {
          id: p.id,
          name,
          yearsExperience: p.yearsExperience,
          averageRating: p.averageRating,
          ratingCount: p.ratingCount,
          certified: p.certified,
          categories: [...new Set(relevant.map((s) => s.category.name))],
          services: relevant.map((s) => ({ id: s.id, name: s.name })),
          startingPrice: prices.length ? Math.min(...prices) : null,
        };
      })
      .filter((p) => p.services.length > 0)
      .filter((p) => query.maxPrice === undefined || (p.startingPrice !== null && p.startingPrice <= query.maxPrice));

    providerResults.sort((a, b) =>
      sort === 'price'
        ? (a.startingPrice ?? Infinity) - (b.startingPrice ?? Infinity) || b.averageRating - a.averageRating
        : b.averageRating - a.averageRating || b.ratingCount - a.ratingCount,
    );

    const serviceResults = services
      .filter(serviceMatches)
      .map((s) => ({
        id: s.id,
        name: s.name,
        categoryName: s.category.name,
        suggestedMinPrice: s.suggestedMinPrice,
        suggestedMaxPrice: s.suggestedMaxPrice,
      }))
      .sort((a, b) =>
        sort === 'price'
          ? (a.suggestedMinPrice ?? Infinity) - (b.suggestedMinPrice ?? Infinity)
          : a.name.localeCompare(b.name),
      );

    return { services: serviceResults, providers: providerResults };
  }

  // Autosuggest: category and service names that start a word with what was
  // typed, categories first, at most eight.
  async suggest(q: string | undefined) {
    const typed = (q ?? '').trim().toLowerCase();
    if (typed.length < 2) return [];
    const [categories, services] = await Promise.all([
      this.prisma.category.findMany({ where: { active: true }, select: { name: true } }),
      this.prisma.subService.findMany({ where: { category: { active: true } }, select: { name: true } }),
    ]);
    const startsAWord = (name: string) => name.toLowerCase().split(/\s+/).some((w) => w.startsWith(typed));
    const names = [...categories.map((c) => c.name), ...services.map((s) => s.name)].filter(startsAWord);
    return [...new Set(names)].slice(0, 8);
  }
}

function normalise(q: string | undefined) {
  return (q ?? '').toLowerCase().split(/\s+/).filter(Boolean);
}

// Every typed word must appear somewhere in the text.
function matchesAll(words: string[], text: string) {
  const haystack = text.toLowerCase();
  return words.every((w) => haystack.includes(w));
}
