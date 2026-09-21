import { CategoriesPage } from './pages/CategoriesPage';

// Provider verification queue, sub-service management, and the notification
// matrix config (docx section 6) are the natural next admin pages — route
// them alongside CategoriesPage as this grows past one screen.
export default function App() {
  return (
    <>
      <header
        style={{
          background: 'var(--oh-primary)',
          color: 'var(--oh-on-primary)',
          padding: '16px 24px',
          fontWeight: 700,
          fontSize: '1.1rem',
        }}
      >
        OneHub Admin
      </header>
      <main>
        <CategoriesPage />
      </main>
    </>
  );
}
