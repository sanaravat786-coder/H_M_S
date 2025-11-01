import React from 'react';
import { Search, Bell, User } from 'lucide-react';
import { useAuth } from '../hooks/useAuth';

const Header = () => {
  const { user, profile } = useAuth();

  return (
    <header className="w-full bg-card dark:bg-dark-card shadow-sm dark:border-b dark:border-dark-muted">
      <div className="flex items-center justify-between h-16 px-6">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-muted-foreground" />
          <input
            type="text"
            placeholder="Search..."
            className="pl-10 pr-4 py-2 w-64 bg-secondary dark:bg-dark-secondary rounded-md text-secondary-foreground focus:outline-none focus:ring-2 focus:ring-accent"
          />
        </div>
        <div className="flex items-center space-x-4">
          <button className="p-2 rounded-full text-muted-foreground hover:bg-muted dark:hover:bg-dark-muted hover:text-card-foreground dark:hover:text-dark-primary-foreground">
            <Bell className="h-6 w-6" />
          </button>
          {user && profile && (
            <div className="flex items-center space-x-2">
              <div className="w-10 h-10 rounded-full bg-accent flex items-center justify-center">
                <User className="h-6 w-6 text-accent-foreground" />
              </div>
              <div className="hidden md:block">
                <p className="font-semibold text-sm text-card-foreground dark:text-dark-card-foreground">{profile.full_name}</p>
                <p className="text-xs text-muted-foreground">{user.email}</p>
              </div>
            </div>
          )}
        </div>
      </div>
    </header>
  );
};

export default Header;
