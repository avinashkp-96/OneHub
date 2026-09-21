import { useEffect, useState } from 'react';
import { Category, createCategory, listCategories } from '../api';

// docx 3.1/3.2 — Admin category and sub-service management.
export function CategoriesPage() {
  const [categories, setCategories] = useState<Category[]>([]);
  const [name, setName] = useState('');
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    listCategories().then(setCategories).catch((e) => setError(String(e)));
  }, []);

  async function handleCreate(e: React.FormEvent) {
    e.preventDefault();
    if (!name.trim()) return;
    try {
      const created = await createCategory({ name });
      setCategories((prev) => [...prev, created]);
      setName('');
    } catch (e) {
      setError(String(e));
    }
  }

  return (
    <section>
      <h1>Service Categories</h1>
      {error && <p role="alert">{error}</p>}
      <form onSubmit={handleCreate}>
        <input
          value={name}
          onChange={(e) => setName(e.target.value)}
          placeholder="e.g. Electrician"
          aria-label="Category name"
        />
        <button type="submit">Add category</button>
      </form>
      <ul>
        {categories.map((c) => (
          <li key={c.id}>
            {c.name} {c.active ? '' : '(inactive)'}
          </li>
        ))}
      </ul>
    </section>
  );
}
