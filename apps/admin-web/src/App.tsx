import { CategoriesPage } from './pages/CategoriesPage';

// Provider verification queue, sub-service management, and the notification
// matrix config (docx section 6) are the natural next admin pages — route
// them alongside CategoriesPage as this grows past one screen.
export default function App() {
  return (
    <main>
      <h1>OneHub Admin</h1>
      <CategoriesPage />
    </main>
  );
}
