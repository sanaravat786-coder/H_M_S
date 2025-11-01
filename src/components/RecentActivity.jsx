import React from 'react';
import { UserPlus, UserCheck, ShieldAlert, Megaphone, AlertCircle } from 'lucide-react';
import { formatDistanceToNow } from 'date-fns';

const iconMap = {
    'user-plus': UserPlus,
    'user-check': UserCheck,
    'shield-alert': ShieldAlert,
    'megaphone': Megaphone,
    'default': AlertCircle,
};

const RecentActivity = ({ activities = [] }) => {
    if (activities.length === 0) {
        return <p className="text-sm text-muted-foreground">No recent activity to display.</p>;
    }

  return (
    <ul className="space-y-4">
      {activities.map((activity) => {
        const Icon = iconMap[activity.icon] || iconMap['default'];
        return (
            <li key={activity.id} className="flex items-start space-x-3">
            <div className="bg-muted dark:bg-dark-muted p-2 rounded-full">
                <Icon className="h-4 w-4 text-muted-foreground" />
            </div>
            <div>
                <p className="text-sm text-card-foreground dark:text-dark-card-foreground">{activity.text}</p>
                <p className="text-xs text-muted-foreground">{formatDistanceToNow(new Date(activity.created_at), { addSuffix: true })}</p>
            </div>
            </li>
        )
        })}
    </ul>
  );
};

export default RecentActivity;
