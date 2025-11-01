import React, { useState, useMemo, useEffect, useCallback } from 'react';
import { format } from 'date-fns';
import PageHeader from '../components/PageHeader';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Select } from '../components/ui/Select';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '../components/ui/Table';
import Badge from '../components/ui/Badge';
import { PlusCircle, Search, Receipt } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useToast } from '../hooks/useToast';
import Spinner from '../components/ui/Spinner';
import Dialog from '../components/ui/Dialog';
import RecordPaymentForm from '../components/RecordPaymentForm';

const FeesPage = () => {
  const [fees, setFees] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState({ term: '', status: 'All' });
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [selectedFee, setSelectedFee] = useState(null);
  const { addToast } = useToast();

  const fetchFees = useCallback(async () => {
    setLoading(true);
    const { data, error } = await supabase
      .from('fees')
      .select('*, students(name)');
    
    if (error) {
      addToast('Failed to fetch fees', { type: 'error' });
    } else {
      setFees(data);
    }
    setLoading(false);
  }, [addToast]);

  useEffect(() => {
    fetchFees();
  }, [fetchFees]);

  const filteredFees = useMemo(() => {
    return fees
      .filter(fee => fee.students.name.toLowerCase().includes(filter.term.toLowerCase()))
      .filter(fee => filter.status === 'All' || fee.status === filter.status);
  }, [fees, filter]);

  const handleOpenPaymentModal = (fee) => {
    setSelectedFee(fee);
    setIsModalOpen(true);
  };

  const handleRecordPayment = async (paymentData) => {
    const { error } = await supabase.rpc('record_payment', paymentData);
    if (error) {
        addToast(`Error: ${error.message}`, { type: 'error' });
    } else {
        addToast('Payment recorded successfully!', { type: 'success' });
        fetchFees();
        setIsModalOpen(false);
        setSelectedFee(null);
    }
  };

  return (
    <>
      <PageHeader title="Fees">
        <Button onClick={() => alert('Generate invoice not implemented yet.')}>
          <PlusCircle className="mr-2 h-4 w-4" />
          Generate Invoice
        </Button>
      </PageHeader>

      <div className="bg-card dark:bg-dark-card p-6 rounded-lg shadow-sm">
        <div className="flex flex-col md:flex-row items-center justify-between gap-4 mb-4">
          <div className="relative w-full md:w-auto">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-muted-foreground" />
            <Input 
              placeholder="Search by student name..." 
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
            <option>Paid</option>
            <option>Pending</option>
            <option>Overdue</option>
          </Select>
        </div>

        {loading ? (
            <div className="flex justify-center items-center h-64"><Spinner size="lg" /></div>
        ) : (
            <Table>
            <TableHeader>
                <TableRow>
                <TableHead>Invoice ID</TableHead>
                <TableHead>Student Name</TableHead>
                <TableHead>Amount</TableHead>
                <TableHead>Due Date</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="text-right">Actions</TableHead>
                </TableRow>
            </TableHeader>
            <TableBody>
                {filteredFees.length > 0 ? filteredFees.map((fee) => (
                <TableRow key={fee.id}>
                    <TableCell className="font-medium">{fee.id.substring(0,8)}</TableCell>
                    <TableCell>{fee.students.name}</TableCell>
                    <TableCell>£{fee.total_amount}</TableCell>
                    <TableCell>{format(new Date(fee.due_date), 'dd MMM, yyyy')}</TableCell>
                    <TableCell><Badge status={fee.status} /></TableCell>
                    <TableCell className="text-right">
                        {fee.status !== 'Paid' && (
                            <Button variant="outline" size="sm" onClick={() => handleOpenPaymentModal(fee)}>
                                <Receipt className="mr-2 h-4 w-4" />
                                Record Payment
                            </Button>
                        )}
                    </TableCell>
                </TableRow>
                )) : (
                <TableRow>
                    <TableCell colSpan={6} className="text-center py-12 text-muted-foreground">
                    No fee records found.
                    </TableCell>
                </TableRow>
                )}
            </TableBody>
            </Table>
        )}
      </div>
      {selectedFee && (
        <Dialog isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} title="Record Payment">
            <RecordPaymentForm onSave={handleRecordPayment} onCancel={() => setIsModalOpen(false)} fee={selectedFee} />
        </Dialog>
      )}
    </>
  );
};

export default FeesPage;
