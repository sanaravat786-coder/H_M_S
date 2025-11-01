import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import { Home, Users, BedDouble, CircleDollarSign, UserCheck, ShieldAlert, Settings, Building, Megaphone, LogOut } from 'lucide-react';
import { clsx } from 'clsx';
import { useAuth } from '../hooks/useAuth';
import { useToast } from '../hooks/useToast';

const adminNav = [
  { name: 'Dashboard', href: '/', icon: Home },
  { name: 'Students', href: '/students', icon: Users },
  { name: 'Rooms', href: '/rooms', icon: BedDouble },
  { name: 'Fees', href: '/fees', icon: CircleDollarSign },
  { name: 'Visitors', href: '/visitors', icon: UserCheck },
  { name: 'Complaints', href: '/complaints', icon: ShieldAlert },
  { name: 'Announcements', href: '/announcements', icon: Megaphone },
];

const wardenNav = [
  { name: 'Dashboard', href: '/', icon: Home },
  { name: 'Students', href: '/students', icon: Users },
  { name: 'Rooms', href: '/rooms', icon: BedDouble },
  { name: 'Visitors', href: '/visitors', icon: UserCheck },
  { name: 'Complaints', href: '/complaints', icon: ShieldAlert },
  { name: 'Announcements', href: '/announcements', icon: Megaphone },
];

const studentNav = [
  { name: 'Dashboard', href: '/', icon: Home },
  { name: 'Announcements', href: '/announcements', icon: Megaphone },
  { name: 'Complaints', href: '/complaints', icon: ShieldAlert },
];


const Sidebar = () => {
    const { signOut, profile } = useAuth();
    const navigate = useNavigate();
    const { addToast } = useToast();

    let navigation = [];
    if (profile?.role === 'Admin') {
        navigation = adminNav;
    } else if (profile?.role === 'Warden') {
        navigation = wardenNav;
    } else {
        navigation = studentNav;
    }

    const handleSignOut = async () => {
        const { error } = await signOut();
        if (error) {
            addToast(error.message, { type: 'error' });
        } else {
            addToast('Signed out successfully', { type: 'success' });
            navigate('/login');
        }
    };

  return (
    <div className="hidden md:flex md:flex-shrink-0">
      <div className="flex flex-col w-64">
        <div className="flex flex-col h-0 flex-1">
          <div className="flex items-center h-16 flex-shrink-0 px-4 bg-primary text-primary-foreground">
            <Building className="h-8 w-8 text-accent" />
            <span className="ml-2 text-xl font-semibold">HMS</span>
          </div>
          <div className="flex-1 flex flex-col overflow-y-auto bg-primary">
            <nav className="flex-1 px-2 py-4 space-y-1">
              {navigation.map((item) => (
                <NavLink
                  key={item.name}
                  to={item.href}
                  end={item.href === '/'}
                  className={({ isActive }) =>
                    clsx(
                      'group flex items-center px-2 py-2 text-sm font-medium rounded-md',
                      isActive
                        ? 'bg-accent text-accent-foreground'
                        : 'text-primary-foreground hover:bg-accent/80 hover:text-accent-foreground'
                    )
                  }
                >
                  <item.icon
                    className="mr-3 flex-shrink-0 h-6 w-6"
                    aria-hidden="true"
                  />
                  {item.name}
                </NavLink>
              ))}
            </nav>
            <div className="mt-auto p-2 space-y-1">
                <NavLink
                  to="/settings"
                  className={({ isActive }) =>
                    clsx(
                      'group flex items-center px-2 py-2 text-sm font-medium rounded-md',
                      isActive
                        ? 'bg-accent text-accent-foreground'
                        : 'text-primary-foreground hover:bg-accent/80 hover:text-accent-foreground'
                    )
                  }
                >
                  <Settings
                    className="mr-3 flex-shrink-0 h-6 w-6"
                    aria-hidden="true"
                  />
                  Settings
                </NavLink>
                <button
                  onClick={handleSignOut}
                  className="group flex items-center w-full px-2 py-2 text-sm font-medium rounded-md text-primary-foreground hover:bg-accent/80 hover:text-accent-foreground"
                >
                  <LogOut
                    className="mr-3 flex-shrink-0 h-6 w-6"
                    aria-hidden="true"
                  />
                  Logout
                </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Sidebar;
