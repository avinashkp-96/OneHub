import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest';
import { createCategory, listCategories } from './api';

describe('categories API client', () => {
  const originalFetch = global.fetch;

  afterEach(() => {
    global.fetch = originalFetch;
  });

  it('lists categories on success', async () => {
    global.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => [{ id: '1', name: 'Electrician', active: true }],
    }) as unknown as typeof fetch;

    const result = await listCategories();
    expect(result).toEqual([{ id: '1', name: 'Electrician', active: true }]);
  });

  it('throws when the categories request fails', async () => {
    global.fetch = vi.fn().mockResolvedValue({ ok: false, status: 500 }) as unknown as typeof fetch;
    await expect(listCategories()).rejects.toThrow('failed to load categories (500)');
  });

  it('throws when creating a category fails', async () => {
    global.fetch = vi.fn().mockResolvedValue({ ok: false, status: 400 }) as unknown as typeof fetch;
    await expect(createCategory({ name: 'Plumber' })).rejects.toThrow('failed to create category (400)');
  });
});
