import React from 'react';

const PageHeader = ({ title, children }) => {
  return (
    <div className="flex flex-col md:flex-row items-start md:items-center justify-between mb-6">
      <div>
        <h1 className="text-3xl font-bold text-card-foreground dark:text-dark-card-foreground">{title}</h1>
        <p className="text-muted-foreground dark:text-dark-muted-foreground mt-1">Manage {title.toLowerCase()} for the entire hostel.</p>
      </div>
      <div className="mt-4 md:mt-0 flex-shrink-0">
        {children}
      </div>
    </div>
  );
};

export default PageHeader;
