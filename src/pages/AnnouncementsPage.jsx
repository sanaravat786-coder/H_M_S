import React, { useState, useEffect, useCallback } from 'react';
import { format } from 'date-fns';
import PageHeader from '../components/PageHeader';
import { Button } from '../components/ui/Button';
import { PlusCircle, Trash2 } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useToast } from '../hooks/useToast';
import Spinner from '../components/ui/Spinner';
import Dialog from '../components/ui/Dialog';
import { Input } from '../components/ui/Input';
import { useAuth } from '../hooks/useAuth';

const AddAnnouncementForm = ({ onSave, onCancel }) => {
    const [title, setTitle] = useState('');
    const [message, setMessage] = useState('');
    const { user } = useAuth();

    const handleSubmit = (e) => {
        e.preventDefault();
        onSave({ title, message, user_id: user.id });
    };

    return (
        <form onSubmit={handleSubmit}>
            <div className="space-y-4">
                <div>
                    <label className="text-sm font-medium text-muted-foreground">Title</label>
                    <Input placeholder="Important Notice" className="mt-1" value={title} onChange={e => setTitle(e.target.value)} required />
                </div>
                <div>
                    <label className="text-sm font-medium text-muted-foreground">Message</label>
                    <textarea 
                        className="mt-1 flex w-full rounded-md border border-muted-foreground/20 bg-transparent px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50 dark:border-dark-muted dark:bg-dark-secondary"
                        rows={4}
                        placeholder="Details about the announcement..."
                        value={message}
                        onChange={e => setMessage(e.target.value)}
                        required
                    />
                </div>
            </div>
            <div className="mt-6 flex justify-end space-x-2">
                <Button type="button" variant="secondary" onClick={onCancel}>Cancel</Button>
                <Button type="submit">Post Announcement</Button>
            </div>
        </form>
    );
};


const AnnouncementsPage = () => {
    const [announcements, setAnnouncements] = useState([]);
    const [loading, setLoading] = useState(true);
    const [isModalOpen, setIsModalOpen] = useState(false);
    const { addToast } = useToast();
    const { profile } = useAuth();

    const fetchAnnouncements = useCallback(async () => {
        setLoading(true);
        const { data, error } = await supabase
            .from('notices')
            .select('*, profiles(full_name)')
            .order('created_at', { ascending: false });
        
        if (error) {
            addToast('Failed to fetch announcements', { type: 'error' });
        } else {
            setAnnouncements(data);
        }
        setLoading(false);
    }, [addToast]);

    useEffect(() => {
        fetchAnnouncements();
    }, [fetchAnnouncements]);

    const handleAddAnnouncement = async (newData) => {
        const { data, error } = await supabase.from('notices').insert([newData]).select('*, profiles(full_name)').single();
        if (error) {
            addToast(`Error: ${error.message}`, { type: 'error' });
        } else {
            addToast('Announcement posted!', { type: 'success' });
            setAnnouncements(prev => [data, ...prev]);
            setIsModalOpen(false);
        }
    };

    const handleDelete = async (id) => {
        if (window.confirm('Are you sure you want to delete this announcement?')) {
            const { error } = await supabase.from('notices').delete().eq('id', id);
            if (error) {
                addToast(`Error: ${error.message}`, { type: 'error' });
            } else {
                addToast('Announcement deleted.', { type: 'success' });
                setAnnouncements(prev => prev.filter(a => a.id !== id));
            }
        }
    };

    return (
        <>
            <PageHeader title="Announcements">
                {profile?.role === 'Admin' && (
                    <Button onClick={() => setIsModalOpen(true)}>
                        <PlusCircle className="mr-2 h-4 w-4" />
                        New Announcement
                    </Button>
                )}
            </PageHeader>

            {loading ? (
                <div className="flex justify-center items-center h-64"><Spinner size="lg" /></div>
            ) : (
                <div className="space-y-6">
                    {announcements.length > 0 ? announcements.map(item => (
                        <div key={item.id} className="bg-card dark:bg-dark-card p-6 rounded-lg shadow-sm">
                            <div className="flex justify-between items-start">
                                <div>
                                    <h3 className="text-lg font-semibold text-card-foreground dark:text-dark-card-foreground">{item.title}</h3>
                                    <p className="text-sm text-muted-foreground">
                                        Posted by {item.profiles.full_name} on {format(new Date(item.created_at), 'dd MMM, yyyy')}
                                    </p>
                                </div>
                                {profile?.role === 'Admin' && (
                                    <Button variant="ghost" size="icon" className="text-red-500 hover:text-red-600" onClick={() => handleDelete(item.id)}>
                                        <Trash2 className="h-4 w-4" />
                                    </Button>
                                )}
                            </div>
                            <p className="mt-4 text-card-foreground/90 dark:text-dark-card-foreground/90 whitespace-pre-wrap">{item.message}</p>
                        </div>
                    )) : (
                        <div className="text-center py-12 text-muted-foreground bg-card dark:bg-dark-card rounded-lg">
                            No announcements found.
                        </div>
                    )}
                </div>
            )}
             <Dialog isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} title="New Announcement">
                <AddAnnouncementForm onSave={handleAddAnnouncement} onCancel={() => setIsModalOpen(false)} />
            </Dialog>
        </>
    );
};

export default AnnouncementsPage;
