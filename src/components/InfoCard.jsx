import React from 'react';
import { cn } from '../lib/utils';

const InfoCard = ({ title, children, className }) => {
  return (
    <div className={cn("bg-card dark:bg-dark-card p-6 rounded-lg shadow-sm", className)}>
      <h3 className="text-lg font-semibold mb-4 text-card-foreground dark:text-dark-card-foreground">{title}</h3>
      {children}
    </div>
  );
};

const InfoRow = ({ label, value }) => {
    return (
        <div className="flex justify-between items-center py-2 border-b border-muted/50 dark:border-dark-muted/50 last:border-b-0">
            <p className="text-sm font-medium text-muted-foreground">{label}</p>
            <p className="text-sm text-card-foreground dark:text-dark-card-foreground">{value}</p>
        </div>
    );
};

export { InfoCard, InfoRow };
