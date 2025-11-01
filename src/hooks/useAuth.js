import { useContext } from 'react';
import { AuthContext } from '../contexts/AuthContext';

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (context === undefined) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  
  const isAdmin = context.profile?.role === 'Admin';
  const isWarden = context.profile?.role === 'Warden';
  const isStudent = context.profile?.role === 'Student';

  return {
    ...context,
    isAdmin,
    isWarden,
    isStudent,
  };
};
