import React, { useState, useEffect } from 'react';
import { Button } from './ui/Button';
import { Input } from './ui/Input';
import { Select } from './ui/Select';
import { supabase } from '../lib/supabase';

const LogVisitorForm = ({ onSave, onCancel }) => {
  const [name, setName] = useState('');
  const [contact, setContact] = useState('');
  const [studentId, setStudentId] = useState('');
  const [purpose, setPurpose] = useState('');
  const [allStudents, setAllStudents] = useState([]);

  useEffect(() => {
    const fetchStudents = async () => {
      const { data } = await supabase.from('students').select('id, name').eq('status', 'Active');
      setAllStudents(data || []);
    };
    fetchStudents();
  }, []);

  const handleSubmit = (e) => {
    e.preventDefault();
    onSave({ 
        p_name: name,
        p_contact: contact,
        p_student_id: studentId,
        p_purpose: purpose,
    });
  };

  return (
    <form onSubmit={handleSubmit}>
      <div className="space-y-4">
        <div>
          <label className="text-sm font-medium text-muted-foreground">Visitor Name</label>
          <Input placeholder="Jane Smith" className="mt-1" value={name} onChange={e => setName(e.target.value)} required />
        </div>
        <div>
          <label className="text-sm font-medium text-muted-foreground">Visitor Contact</label>
          <Input placeholder="+44 9876 543210" className="mt-1" value={contact} onChange={e => setContact(e.target.value)} required />
        </div>
        <div>
          <label className="text-sm font-medium text-muted-foreground">Student to Visit</label>
          <Select className="mt-1" value={studentId} onChange={e => setStudentId(e.target.value)} required>
            <option value="">Select a student</option>
            {allStudents.map(student => (
              <option key={student.id} value={student.id}>{student.name}</option>
            ))}
          </Select>
        </div>
        <div>
          <label className="text-sm font-medium text-muted-foreground">Purpose of Visit</label>
          <Input placeholder="Meeting" className="mt-1" value={purpose} onChange={e => setPurpose(e.target.value)} required />
        </div>
      </div>
      <div className="mt-6 flex justify-end space-x-2">
        <Button type="button" variant="secondary" onClick={onCancel}>Cancel</Button>
        <Button type="submit">Log Visitor</Button>
      </div>
    </form>
  );
};

export default LogVisitorForm;
