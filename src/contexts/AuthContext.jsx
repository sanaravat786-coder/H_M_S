import React, { createContext, useState, useEffect, useMemo } from 'react';
import { supabase } from '../lib/supabase';
import Spinner from '../components/ui/Spinner';

export const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [session, setSession] = useState(null);
  const [profile, setProfile] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchUserAndProfile = async () => {
      try {
        const { data: { session: currentSession } } = await supabase.auth.getSession();
        setSession(currentSession);
        setUser(currentSession?.user ?? null);

        if (currentSession?.user) {
          const { data: userProfile } = await supabase
            .from('profiles')
            .select('*, students:students(id)')
            .eq('id', currentSession.user.id)
            .single();
          
          // Attach student_id to profile if it exists
          const profileWithStudentId = userProfile ? { ...userProfile, student_id: userProfile.students[0]?.id } : null;
          setProfile(profileWithStudentId);
        }
      } catch (error) {
        console.error("Error fetching initial user profile:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchUserAndProfile();

    const { data: authListener } = supabase.auth.onAuthStateChange(
      async (_event, session) => {
        setSession(session);
        setUser(session?.user ?? null);
        if (session?.user) {
          const { data: userProfile } = await supabase
            .from('profiles')
            .select('*, students:students(id)')
            .eq('id', session.user.id)
            .single();
          
          const profileWithStudentId = userProfile ? { ...userProfile, student_id: userProfile.students[0]?.id } : null;
          setProfile(profileWithStudentId);
        } else {
          setProfile(null);
        }
        if (_event === 'SIGNED_IN') {
            setLoading(false);
        }
      }
    );

    return () => {
      authListener.subscription.unsubscribe();
    };
  }, []);

  const value = useMemo(() => ({
    signUp: (data) => supabase.auth.signUp(data),
    signIn: (data) => supabase.auth.signInWithPassword(data),
    signOut: () => supabase.auth.signOut(),
    user,
    session,
    profile,
    loading,
  }), [user, session, profile, loading]);

  if (loading) {
    return (
      <div className="flex items-center justify-center h-screen bg-gray-50 dark:bg-gray-900">
        <Spinner size="lg" />
      </div>
    );
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
};
