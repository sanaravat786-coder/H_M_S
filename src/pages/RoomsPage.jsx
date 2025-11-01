import React, { useState, useMemo, useEffect, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import PageHeader from '../components/PageHeader';
import { Button } from '../components/ui/Button';
import { Input } from '../components/ui/Input';
import { Select } from '../components/ui/Select';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '../components/ui/Table';
import Badge from '../components/ui/Badge';
import { PlusCircle, Search, Pencil, Trash2 } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useToast } from '../hooks/useToast';
import Spinner from '../components/ui/Spinner';
import Dialog from '../components/ui/Dialog';
import AddRoomForm from '../components/AddRoomForm';

const RoomsPage = () => {
  const [rooms, setRooms] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState({ term: '', status: 'All', type: 'All' });
  const [isModalOpen, setIsModalOpen] = useState(false);
  const navigate = useNavigate();
  const { addToast } = useToast();

  const fetchRooms = useCallback(async () => {
    setLoading(true);
    const { data, error } = await supabase
      .from('rooms')
      .select('*, students(name)');
    
    if (error) {
      addToast('Failed to fetch rooms', { type: 'error' });
    } else {
      setRooms(data);
    }
    setLoading(false);
  }, [addToast]);

  useEffect(() => {
    fetchRooms();
  }, [fetchRooms]);

  const filteredRooms = useMemo(() => {
    return rooms
      .filter(room => room.room_no.toLowerCase().includes(filter.term.toLowerCase()))
      .filter(room => filter.status === 'All' || room.status === filter.status)
      .filter(room => filter.type === 'All' || room.type === filter.type);
  }, [rooms, filter]);

  const handleAddRoom = async (newRoomData) => {
    const { data, error } = await supabase.rpc('add_room', newRoomData);
    if (error) {
        addToast(`Error: ${error.message}`, { type: 'error' });
    } else {
        addToast('Room added successfully!', { type: 'success' });
        fetchRooms();
        setIsModalOpen(false);
    }
  };

  const handleRowClick = (roomId) => {
    navigate(`/rooms/${roomId}`);
  };

  return (
    <>
      <PageHeader title="Rooms">
        <Button onClick={() => setIsModalOpen(true)}>
          <PlusCircle className="mr-2 h-4 w-4" />
          Add Room
        </Button>
      </PageHeader>

      <div className="bg-card dark:bg-dark-card p-6 rounded-lg shadow-sm">
        <div className="flex flex-col md:flex-row items-center justify-between gap-4 mb-4">
          <div className="relative w-full md:w-auto">
            <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-muted-foreground" />
            <Input 
              placeholder="Search by room no..." 
              className="pl-10 w-full md:w-64"
              value={filter.term}
              onChange={(e) => setFilter(prev => ({...prev, term: e.target.value}))}
            />
          </div>
          <div className="flex gap-4 w-full md:w-auto">
            <Select 
              className="w-full md:w-40"
              value={filter.status}
              onChange={(e) => setFilter(prev => ({...prev, status: e.target.value}))}
            >
              <option>All Status</option>
              <option>Available</option>
              <option>Occupied</option>
              <option>Maintenance</option>
            </Select>
            <Select 
              className="w-full md:w-40"
              value={filter.type}
              onChange={(e) => setFilter(prev => ({...prev, type: e.target.value}))}
            >
              <option>All Types</option>
              <option>Single</option>
              <option>Double</option>
              <option>Triple</option>
            </Select>
          </div>
        </div>

        {loading ? (
            <div className="flex justify-center items-center h-64"><Spinner size="lg" /></div>
        ) : (
            <Table>
            <TableHeader>
                <TableRow>
                <TableHead>Room No</TableHead>
                <TableHead>Block</TableHead>
                <TableHead>Type</TableHead>
                <TableHead>Occupant</TableHead>
                <TableHead>Status</TableHead>
                <TableHead className="text-right">Actions</TableHead>
                </TableRow>
            </TableHeader>
            <TableBody>
                {filteredRooms.length > 0 ? filteredRooms.map((room) => (
                <TableRow key={room.id} onClick={() => handleRowClick(room.id)} className="cursor-pointer">
                    <TableCell className="font-medium">{room.room_no}</TableCell>
                    <TableCell>{room.block}</TableCell>
                    <TableCell>{room.type}</TableCell>
                    <TableCell>{room.students[0]?.name || <span className="text-muted-foreground">N/A</span>}</TableCell>
                    <TableCell><Badge status={room.status} /></TableCell>
                    <TableCell className="text-right">
                    <div className="flex justify-end gap-2">
                        <Button variant="ghost" size="icon" onClick={(e) => {e.stopPropagation(); alert('Edit not implemented yet.')}}><Pencil className="h-4 w-4" /></Button>
                        <Button variant="ghost" size="icon" className="text-red-500 hover:text-red-600" onClick={(e) => {e.stopPropagation(); alert('Delete not implemented yet.')}}><Trash2 className="h-4 w-4" /></Button>
                    </div>
                    </TableCell>
                </TableRow>
                )) : (
                <TableRow>
                    <TableCell colSpan={6} className="text-center py-12 text-muted-foreground">
                    No rooms found.
                    </TableCell>
                </TableRow>
                )}
            </TableBody>
            </Table>
        )}
      </div>
      <Dialog isOpen={isModalOpen} onClose={() => setIsModalOpen(false)} title="Add New Room">
        <AddRoomForm onSave={handleAddRoom} onCancel={() => setIsModalOpen(false)} />
      </Dialog>
    </>
  );
};

export default RoomsPage;
