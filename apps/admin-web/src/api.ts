const BASE_URL = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:3000/api/v1';

export interface Category {
  id: string;
  name: string;
  iconUrl?: string;
  description?: string;
  active: boolean;
}

function authHeaders(): HeadersInit {
  const token = localStorage.getItem('admin_token');
  return token ? { Authorization: `Bearer ${token}` } : {};
}

export async function listCategories(): Promise<Category[]> {
  const res = await fetch(`${BASE_URL}/categories`);
  if (!res.ok) throw new Error(`failed to load categories (${res.status})`);
  return res.json();
}

export async function createCategory(input: Omit<Category, 'id' | 'active'>): Promise<Category> {
  const res = await fetch(`${BASE_URL}/categories`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...authHeaders() },
    body: JSON.stringify(input),
  });
  if (!res.ok) throw new Error(`failed to create category (${res.status})`);
  return res.json();
}
