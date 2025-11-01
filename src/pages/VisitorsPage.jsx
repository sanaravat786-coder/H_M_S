import React, { useState, useMemo, useEffect, useCallback } from 'react';
import { format } from 'date-fns';
import PageHeader from '../components/PageHeader';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '../components/ui/Table';
import { PlusCircle, Search, LogOut } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useToast } from '../hooks/useToast';
import Spinner from '../components/ui/Spinner';
import Dialog from '../components/ui/Dialog';
import LogVisitorForm from '../components/LogVisitorForm';

const VisitorsPage = () => {
  const [visitors, setVisitors] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const { addToast } = useToast();

  const fetchVisitors = useCallback(async () => {
    setLoading(true);
    const { data, error } = await supabase
      .from('visitors')
      .select('*, students(name, rooms(room_no))')
      .order('in_time', { ascending: false });
    
    if (error) {
      addToast('Failed to fetch visitors', { type: 'error' });
    } else {
      setVisitors(data);
    }
    setLoading(false);
  }, [addToast]);

  useEffect(() => {
    fetchVisitors();
  }, [fetchVisitors]);

  const filteredVisitors = useMemo(() => {
    return visitors.filter(v => 
      v.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      v.students?.name.toLowerCase().includes(searchTerm.toLowerCase())
    );
  }, [visitors, searchTerm]);

  const handleLogVisitor = async (newVisitorData) => {
    const { error } = await supabase.rpc('log_visitor', newVisitorData);
    if (error) {
        addToast(`Error: ${error.message}`, { type: 'error' });
    } else {
        addToast('Visitor logged successfully!', { type: 'success' });
        fetchVisitors();
        setIsModalOpen(false);
    }
  };

  const handleCheckOut = async (visitorId) => {
    const { error } = await supabase.rpc('checkout_visitor', { p_visitor_id: visitorId });
    if (error) {
        addToast(`Error: ${error.message}`, { type: 'error' });
    } else {
        addToast('Visitor checked out.', { type: 'success' });
        fetchVisitors();
    }
  };

  return (
    <>
      <PageHeader title="Visitors">
        <Button onClick={() => setIsModalOpen(true)}>
          <PlusCircle className="mr-2 h-4 w-4" />
          Log Visitor
        </Button>
      </PageHeader>

      <div className="bg-card dark:bg-dark-card p-6 rounded-lg shadow-sm">
        <div className="flex items-center justify-between gap-4 mb-4">
          <div className="relative w-full md:w-auto">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-muted-foreground" />
            <Input 
              placeholder="Search by name..." 
              className="pl-10 w-full md:w-64"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
        </div>

        {loading ? (
            <div className="flex justify-center items-center h-64"><Spinner size="lg" /></div>
        ) : (
            <Table>
            <TableHeader>
                <TableRow>
                <TableHead>Visitor</TableHead>
                <TableHead>Student Visited</TableHead>
                <TableHead>Room No</TableHead>
                <TableHead>Check-in</TableHead>
                <TableHead>Check-out</TableHead>
                <TableHead className="text-right">Actions</TableHead>
                </TableRow>
            </TableHeader>
            <TableBody>
                {filteredVisitors.length > 0 ? filteredVisitors.map((visitor) => (
                <TableRow key={visitor.id}>
                    <TableCell className="font-medium">{visitor.name}</TableCell>
                    <TableCell>{visitor.students?.name || 'N/A'}</TableCell>
                    <TableCell>{visitor.students?.rooms?.room_no || 'N/A'}</TableCell>
                    <TableCell>{format(new Date(visitor.in_time), 'dd MMM, hh:mm a')}</TableCell>
                    <TableCell>
                    {visitor.out_time ? format(new Date(visitor.out_time), 'dd MMM, hh:mm a') : <span className="text-muted-foreground">Not checked out</span>}
                    </TableCell>
                    <TableCell className="text-right">
                    {!visitor.out_time && (
                        <Button variant="ghost" size="sm" onClick={() => handleCheckOut(visitor.id)}>
                        <LogOut className="mr-2 h-4 w-4" />
                        Check Out
                        </Button>
                    )}
                    </TableCell>
                </TableRow>
                )) : (
                <TableRow>
                    <TableCell colSpan={6} className="text-center py-12 text-muted-foreground">
                    No visitor records found.
                    </TableCell>
                </TableRow>
                )}
            </TableBody>
            </Table>
        )}
      </div>
      <Dialog isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} title="Log New Visitor">
        <LogVisitorForm onSave={handleLogVisitor} onCancel={() => setIsModalOpen(false)} />
      </Dialog>
    </>
  );
};

export default VisitorsPage;
