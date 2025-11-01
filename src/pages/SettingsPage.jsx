import React, { useState } from 'react';
import PageHeader from '../components/PageHeader';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { useAuth } from '../hooks/useAuth';
import { useToast } from '../hooks/useToast';
import { supabase } from '../lib/supabase';

const SettingsPage = () => {
  const { user, profile, loading } = useAuth();
  const { addToast } = useToast();
  const [fullName, setFullName] = useState(profile?.full_name || '');
  const [isSaving, setIsSaving] = useState(false);

  const handleProfileUpdate = async (e) => {
    e.preventDefault();
    setIsSaving(true);
    const { error } = await supabase
      .from('profiles')
      .update({ full_name: fullName })
      .eq('id', user.id);
    
    if (error) {
      addToast(error.message, { type: 'error' });
    } else {
      addToast('Profile updated successfully!', { type: 'success' });
      // Note: The AuthContext will eventually update the profile, but we can force a refresh if needed.
    }
    setIsSaving(false);
  };

  return (
    <>
      <PageHeader title="Settings" />

      <div className="space-y-8">
        <div className="bg-card dark:bg-dark-card p-6 rounded-lg shadow-sm">
          <h3 className="text-lg font-semibold mb-4">Profile</h3>
          <form onSubmit={handleProfileUpdate} className="space-y-4 max-w-md">
            <div>
              <label className="text-sm font-medium text-muted-foreground">Full Name</label>
              <Input 
                value={fullName} 
                onChange={(e) => setFullName(e.target.value)} 
                className="mt-1" 
                disabled={loading || isSaving}
              />
            </div>
            <div>
              <label className="text-sm font-medium text-muted-foreground">Email</label>
              <Input type="email" value={user?.email || ''} className="mt-1" disabled />
            </div>
            <Button type="submit" disabled={loading || isSaving}>
              {isSaving ? 'Saving...' : 'Save Changes'}
            </Button>
          </form>
        </div>

        <div className="bg-card dark:bg-dark-card p-6 rounded-lg shadow-sm">
          <h3 className="text-lg font-semibold mb-4">Security</h3>
          <div className="space-y-4 max-w-md">
            <p className="text-sm text-muted-foreground">Password change functionality is not implemented in this demo.</p>
            <Button disabled>Update Password</Button>
          </div>
        </div>
      </div>
    </>
  );
};

export default SettingsPage;
