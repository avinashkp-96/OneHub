import { Controller, Get, Query } from '@nestjs/common';
import { SearchQueryDto } from './dto/search-query.dto';
import { SearchService } from './search.service';

// Public, like GET /providers and GET /categories: it only returns what a
// customer may browse (active providers' public fields, active categories).
@Controller('search')
export class SearchController {
  constructor(private readonly searchService: SearchService) {}

  @Get()
  search(@Query() query: SearchQueryDto) {
    return this.searchService.search(query);
  }

  @Get('suggest')
  suggest(@Query('q') q?: string) {
    return this.searchService.suggest(q);
  }
}
