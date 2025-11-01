import React, { useState, useMemo, useEffect, useCallback } from 'react';
import { format } from 'date-fns';
import PageHeader from '../components/PageHeader';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Select } from '../components/ui/Select';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '../components/ui/Table';
import Badge from '../components/ui/Badge';
import { PlusCircle, Search, CheckCircle } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useToast } from '../hooks/useToast';
import { useAuth } from '../hooks/useAuth';
import Spinner from '../components/ui/Spinner';
import Dialog from '../components/ui/Dialog';
import AddComplaintForm from '../components/AddComplaintForm';

const ComplaintsPage = () => {
  const [complaints, setComplaints] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState({ term: '', status: 'All' });
  const [isModalOpen, setIsModalOpen] = useState(false);
  const { addToast } = useToast();
  const { isStudent, isAdmin, isWarden } = useAuth();

  const fetchComplaints = useCallback(async () => {
    setLoading(true);
    const { data, error } = await supabase
      .from('complaints')
      .select('*, students(name, rooms(room_no))')
      .order('created_at', { ascending: false });
    
    if (error) {
      addToast('Failed to fetch complaints', { type: 'error' });
    } else {
      setComplaints(data);
    }
    setLoading(false);
  }, [addToast]);

  useEffect(() => {
    fetchComplaints();
  }, [fetchComplaints]);

  const filteredComplaints = useMemo(() => {
    return complaints
      .filter(c => c.students?.name.toLowerCase().includes(filter.term.toLowerCase()) || c.description.toLowerCase().includes(filter.term.toLowerCase()))
      .filter(c => filter.status === 'All' || c.status === filter.status);
  }, [complaints, filter]);

  const handleAddComplaint = async (newData) => {
    const { error } = await supabase.rpc('add_complaint', newData);
    if (error) {
        addToast(`Error: ${error.message}`, { type: 'error' });
    } else {
        addToast('Complaint submitted successfully!', { type: 'success' });
        fetchComplaints();
        setIsModalOpen(false);
    }
  };

  const handleResolve = async (complaintId) => {
    const { error } = await supabase.rpc('resolve_complaint', { p_complaint_id: complaintId });
    if (error) {
        addToast(`Error: ${error.message}`, { type: 'error' });
    } else {
        addToast('Complaint marked as resolved.', { type: 'success' });
        fetchComplaints();
    }
  };

  return (
    <>
      <PageHeader title="Complaints">
        {isStudent && (
            <Button onClick={() => setIsModalOpen(true)}>
                <PlusCircle className="mr-2 h-4 w-4" />
                New Complaint
            </Button>
        )}
      </PageHeader>

      <div className="bg-card dark:bg-dark-card p-6 rounded-lg shadow-sm">
        <div className="flex flex-col md:flex-row items-center justify-between gap-4 mb-4">
          <div className="relative w-full md:w-auto">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-muted-foreground" />
            <Input 
              placeholder="Search by student or issue..." 
              className="pl-10 w-full md:w-64"
              value={filter.term}
              onChange={(e) => setFilter(prev => ({...prev, term: e.target.value}))}
            />
          </div>
          <Select 
            className="w-full md:w-40"
            value={filter.status}
            onChange={(e) => setFilter(prev => ({...prev, status: e.target.value}))}
          >
            <option>All Status</option>
            <option>Pending</option>
            <option>In Progress</option>
            <option>Resolved</option>
          </Select>
        </div>

        {loading ? (
            <div className="flex justify-center items-center h-64"><Spinner size="lg" /></div>
        ) : (
            <Table>
            <TableHeader>
                <TableRow>
                <TableHead>Complaint ID</TableHead>
                <TableHead>Student</TableHead>
                <TableHead>Issue</TableHead>
                <TableHead>Date</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="text-right">Actions</TableHead>
                </TableRow>
            </TableHeader>
            <TableBody>
                {filteredComplaints.length > 0 ? filteredComplaints.map((complaint) => (
                <TableRow key={complaint.id}>
                    <TableCell className="font-medium">{complaint.id.substring(0,8)}</TableCell>
                    <TableCell>{complaint.students?.name} ({complaint.students?.rooms?.room_no})</TableCell>
                    <TableCell className="max-w-xs truncate">{complaint.title}</TableCell>
                    <TableCell>{format(new Date(complaint.created_at), 'dd MMM, yyyy')}</TableCell>
                    <TableCell><Badge status={complaint.status} /></TableCell>
                    <TableCell className="text-right">
                    {(isAdmin || isWarden) && complaint.status !== 'Resolved' && (
                        <Button variant="ghost" size="sm" onClick={() => handleResolve(complaint.id)}>
                        <CheckCircle className="mr-2 h-4 w-4" />
                        Mark Resolved
                        </Button>
                    )}
                    </TableCell>
                </TableRow>
                )) : (
                <TableRow>
                    <TableCell colSpan={6} className="text-center py-12 text-muted-foreground">
                    No complaints found.
                    </TableCell>
                </TableRow>
                )}
            </TableBody>
            </Table>
        )}
      </div>
      <Dialog isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} title="Submit New Complaint">
        <AddComplaintForm onSave={handleAddComplaint} onCancel={() => setIsModalOpen(false)} />
      </Dialog>
    </>
  );
};

export default ComplaintsPage;
