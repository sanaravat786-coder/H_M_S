import React from 'react';
import { cn } from '../../lib/utils';

const badgeVariants = {
    'Pending': 'bg-yellow-100 text-yellow-800 dark:bg-yellow-900/50 dark:text-yellow-300',
    'In Progress': 'bg-blue-100 text-blue-800 dark:bg-blue-900/50 dark:text-blue-300',
    'Resolved': 'bg-green-100 text-green-800 dark:bg-green-900/50 dark:text-green-300',
    'Active': 'bg-green-100 text-green-800 dark:bg-green-900/50 dark:text-green-300',
    'Inactive': 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300',
    'Occupied': 'bg-red-100 text-red-800 dark:bg-red-900/50 dark:text-red-300',
    'Available': 'bg-green-100 text-green-800 dark:bg-green-900/50 dark:text-green-300',
    'Maintenance': 'bg-orange-100 text-orange-800 dark:bg-orange-900/50 dark:text-orange-300',
    'Paid': 'bg-green-100 text-green-800 dark:bg-green-900/50 dark:text-green-300',
    'Overdue': 'bg-red-100 text-red-800 dark:bg-red-900/50 dark:text-red-300',
};

const Badge = ({ status }) => {
  return (
    <span
      className={cn(
        'px-2.5 py-1 text-xs font-semibold rounded-full inline-block',
        badgeVariants[status] || 'bg-gray-100 text-gray-800 dark:bg-gray-700 dark:text-gray-300'
      )}
    >
      {status}
    </span>
  );
};

export default Badge;
