import React from 'react';
import { Outlet } from 'react-router-dom';
import { Building } from 'lucide-react';

const AuthLayout = () => {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center bg-gray-50 p-4 dark:bg-gray-900">
      <div className="mb-8 flex items-center text-2xl font-semibold text-gray-900 dark:text-white">
        <Building className="mr-3 h-8 w-8 text-accent" />
        Hostel Management System
      </div>
      <div className="w-full max-w-md rounded-lg bg-card p-6 shadow dark:border dark:border-dark-muted dark:bg-dark-card sm:p-8">
        <Outlet />
      </div>
    </div>
  );
};

export default AuthLayout;
