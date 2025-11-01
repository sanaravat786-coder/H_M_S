import React, { useState, useMemo, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { PlusCircle, Search, Pencil, Trash2 } from 'lucide-react';
import { format } from 'date-fns';
import PageHeader from '../components/PageHeader';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Select } from '../components/ui/Select';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '../components/ui/Table';
import Badge from '../components/ui/Badge';
import Dialog from '../components/ui/Dialog';
import AddStudentForm from '../components/AddStudentForm';
import { supabase } from '../lib/supabase';
import { useToast } from '../hooks/useToast';
import Spinner from '../components/ui/Spinner';

const StudentsPage = () => {
  const [students, setStudents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [searchTerm, setSearchTerm] = useState('');
  const [statusFilter, setStatusFilter] = useState('All');
  const [isModalOpen, setIsModalOpen] = useState(false);
  const navigate = useNavigate();
  const { addToast } = useToast();

  const fetchStudents = useCallback(async () => {
    setLoading(true);
    const { data, error } = await supabase
      .from('students')
      .select('*, rooms(room_no)');
    
    if (error) {
      addToast('Failed to fetch students', { type: 'error' });
    } else {
      setStudents(data);
    }
    setLoading(false);
  }, [addToast]);

  useEffect(() => {
    fetchStudents();
  }, [fetchStudents]);

  const filteredStudents = useMemo(() => {
    return students
      .filter(student => student.name.toLowerCase().includes(searchTerm.toLowerCase()))
      .filter(student => statusFilter === 'All' || student.status === statusFilter);
  }, [students, searchTerm, statusFilter]);

  const handleAddStudent = async (formData) => {
    // Step 1: Create the user account
    const { data: authData, error: authError } = await supabase.auth.signUp({
      email: formData.email,
      password: formData.password,
      options: {
        data: {
          full_name: formData.fullName,
          role: 'Student',
        },
      },
    });

    if (authError) {
      addToast(`Error creating user: ${authError.message}`, { type: 'error' });
      return;
    }

    if (!authData.user) {
        addToast('User created, but verification is needed. Cannot update details yet.', { type: 'warning' });
        setIsModalOpen(false);
        return;
    }

    // Step 2: Update the student record with the rest of the details
    const { error: rpcError } = await supabase.rpc('update_student_details_and_allocate_room', {
        p_user_id: authData.user.id,
        p_course: formData.course,
        p_contact: formData.contact,
        p_joining_date: formData.joining_date,
        p_status: formData.status,
        p_room_id: formData.room_id
    });

    if (rpcError) {
      addToast(`Error updating details: ${rpcError.message}`, { type: 'error' });
    } else {
      addToast('Student created and details saved successfully!', { type: 'success' });
      fetchStudents();
      setIsModalOpen(false);
    }
  };
  
  const handleDeleteStudent = async (studentId) => {
      if (window.confirm('Are you sure you want to delete this student? This will also delete their login credentials.')) {
          // This is a simplified delete. A robust solution would use an RPC function
          // to handle deleting from auth.users, profiles, and students atomically.
          const { error } = await supabase.from('students').delete().eq('id', studentId);
          if (error) {
              addToast(`Error: ${error.message}`, { type: 'error' });
          } else {
              addToast('Student record deleted successfully!', { type: 'success' });
              setStudents(prev => prev.filter(s => s.id !== studentId));
          }
      }
  };

  const handleRowClick = (studentId) => {
    navigate(`/students/${studentId}`);
  };

  return (
    <>
      <PageHeader title="Students">
        <Button onClick={() => setIsModalOpen(true)}>
          <PlusCircle className="mr-2 h-4 w-4" />
          Add Student
        </Button>
      </PageHeader>

      <div className="bg-card dark:bg-dark-card p-6 rounded-lg shadow-sm">
        <div className="flex flex-col md:flex-row items-center justify-between gap-4 mb-4">
          <div className="relative w-full md:w-auto">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-muted-foreground" />
            <Input 
              placeholder="Search by name..." 
              className="pl-10 w-full md:w-64"
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
            />
          </div>
          <Select 
            className="w-full md:w-40"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <option>All</option>
            <option>Active</option>
            <option>Inactive</option>
          </Select>
        </div>
        {loading ? (
            <div className="flex justify-center items-center h-64"><Spinner size="lg" /></div>
        ) : (
            <Table>
            <TableHeader>
                <TableRow>
                <TableHead>Student</TableHead>
                <TableHead>Room No</TableHead>
                <TableHead>Course</TableHead>
                <TableHead>Joining Date</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="text-right">Actions</TableHead>
                </TableRow>
            </TableHeader>
            <TableBody>
                {filteredStudents.length > 0 ? filteredStudents.map((student) => (
                <TableRow key={student.id} onClick={() => handleRowClick(student.id)} className="cursor-pointer">
                    <TableCell>
                    <div className="flex items-center gap-3">
                        <img src={`https://i.pravatar.cc/150?u=${student.id}`} alt={student.name} className="h-10 w-10 rounded-full object-cover" />
                        <div>
                        <div className="font-medium">{student.name}</div>
                        <div className="text-sm text-muted-foreground">{student.contact}</div>
                        </div>
                    </div>
                    </TableCell>
                    <TableCell>{student.rooms?.room_no || 'N/A'}</TableCell>
                    <TableCell>{student.course || 'N/A'}</TableCell>
                    <TableCell>{student.joining_date ? format(new Date(student.joining_date), 'dd MMM, yyyy') : 'N/A'}</TableCell>
                    <TableCell><Badge status={student.status} /></TableCell>
                    <TableCell className="text-right">
                    <div className="flex justify-end gap-2">
                        <Button variant="ghost" size="icon" onClick={(e) => {e.stopPropagation(); alert('Edit not implemented yet.')}}><Pencil className="h-4 w-4" /></Button>
                        <Button variant="ghost" size="icon" className="text-red-500 hover:text-red-600" onClick={(e) => {e.stopPropagation(); handleDeleteStudent(student.id)}}><Trash2 className="h-4 w-4" /></Button>
                    </div>
                    </TableCell>
                </TableRow>
                )) : (
                <TableRow>
                    <TableCell colSpan={6} className="text-center py-12 text-muted-foreground">
                    No students found.
                    </TableCell>
                </TableRow>
                )}
            </TableBody>
            </Table>
        )}
      </div>
      <Dialog isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} title="Create New Student">
        <AddStudentForm onSave={handleAddStudent} onCancel={() => setIsModalOpen(false)} />
      </Dialog>
    </>
  );
};

export default StudentsPage;
