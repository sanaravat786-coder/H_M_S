import React, { useState, useEffect } from 'react';
import { Button } from './ui/Button';
import { Input } from './ui/Input';
import { Select } from './ui/Select';
import { supabase } from '../lib/supabase';

const AddStudentForm = ({ onSave, onCancel }) => {
  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [course, setCourse] = useState('');
  const [contact, setContact] = useState('');
  const [joiningDate, setJoiningDate] = useState(new Date().toISOString().split('T')[0]);
  const [roomId, setRoomId] = useState('');
  const [status, setStatus] = useState('Active');
  const [availableRooms, setAvailableRooms] = useState([]);

  useEffect(() => {
    const fetchAvailableRooms = async () => {
      const { data, error } = await supabase
        .from('rooms')
        .select('id, room_no')
        .eq('status', 'Available');
      if (!error) {
        setAvailableRooms(data);
      }
    };
    fetchAvailableRooms();
  }, []);

  const handleSubmit = (e) => {
    e.preventDefault();
    onSave({ 
        fullName,
        email,
        password,
        course, 
        contact, 
        joining_date: joiningDate, 
        room_id: roomId || null,
        status 
    });
  };

  return (
    <form onSubmit={handleSubmit}>
      <div className="space-y-4">
        <div>
          <label className="text-sm font-medium text-muted-foreground">Full Name</label>
          <Input placeholder="John Doe" className="mt-1" value={fullName} onChange={e => setFullName(e.target.value)} required />
        </div>
        <div>
          <label className="text-sm font-medium text-muted-foreground">Email Address</label>
          <Input type="email" placeholder="student@example.com" className="mt-1" value={email} onChange={e => setEmail(e.target.value)} required />
        </div>
        <div>
          <label className="text-sm font-medium text-muted-foreground">Initial Password</label>
          <Input type="password" placeholder="••••••••" className="mt-1" value={password} onChange={e => setPassword(e.target.value)} required />
        </div>
        <div>
          <label className="text-sm font-medium text-muted-foreground">Course</label>
          <Input placeholder="Computer Science" className="mt-1" value={course} onChange={e => setCourse(e.target.value)} required />
        </div>
        <div>
          <label className="text-sm font-medium text-muted-foreground">Contact</label>
          <Input placeholder="+44 1234 567890" className="mt-1" value={contact} onChange={e => setContact(e.target.value)} required />
        </div>
        <div>
          <label className="text-sm font-medium text-muted-foreground">Joining Date</label>
          <Input type="date" className="mt-1" value={joiningDate} onChange={e => setJoiningDate(e.target.value)} required />
        </div>
        <div>
          <label className="text-sm font-medium text-muted-foreground">Assign Room</label>
          <Select className="mt-1" value={roomId} onChange={e => setRoomId(e.target.value)}>
            <option value="">Not Assigned</option>
            {availableRooms.map(room => (
              <option key={room.id} value={room.id}>{room.room_no}</option>
            ))}
          </Select>
        </div>
        <div>
          <label className="text-sm font-medium text-muted-foreground">Status</label>
          <Select className="mt-1" value={status} onChange={e => setStatus(e.target.value)}>
            <option>Active</option>
            <option>Inactive</option>
          </Select>
        </div>
      </div>
      <div className="mt-6 flex justify-end space-x-2">
        <Button type="button" variant="secondary" onClick={onCancel}>Cancel</Button>
        <Button type="submit">Create Student</Button>
      </div>
    </form>
  );
};

export default AddStudentForm;
