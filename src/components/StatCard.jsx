import React from 'react';

const StatCard = ({ title, value, icon: Icon }) => {
  return (
    <div className="bg-card dark:bg-dark-card p-6 rounded-lg shadow-sm flex items-center justify-between">
      <div>
        <p className="text-sm font-medium text-muted-foreground">{title}</p>
        <p className="text-2xl font-bold text-card-foreground dark:text-dark-card-foreground">{value}</p>
      </div>
      <div className="bg-accent/10 p-3 rounded-full">
        <Icon className="h-6 w-6 text-accent" />
      </div>
    </div>
  );
};

export default StatCard;
