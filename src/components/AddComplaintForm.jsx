import React, { useState } from 'react';
import { Button } from './ui/Button';
import { Input } from './ui/Input';
import { useAuth } from '../hooks/useAuth';

const AddComplaintForm = ({ onSave, onCancel }) => {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const { profile } = useAuth(); // Assuming student info is in profile

  const handleSubmit = (e) => {
    e.preventDefault();
    // The RPC will get the student_id from the authenticated user
    onSave({ 
        p_title: title,
        p_description: description,
        p_student_id: profile.student_id // Assumes student_id is on the profile
    });
  };

  return (
    <form onSubmit={handleSubmit}>
      <div className="space-y-4">
        <div>
          <label className="text-sm font-medium text-muted-foreground">Issue Title</label>
          <Input placeholder="e.g., Leaky Faucet" className="mt-1" value={title} onChange={e => setTitle(e.target.value)} required />
        </div>
        <div>
          <label className="text-sm font-medium text-muted-foreground">Description</label>
          <textarea 
            className="mt-1 flex w-full rounded-md border border-muted-foreground/20 bg-transparent px-3 py-2 text-sm ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50 dark:border-dark-muted dark:bg-dark-secondary"
            rows={4}
            placeholder="Please provide details about the issue..."
            value={description}
            onChange={e => setDescription(e.target.value)}
            required
          />
        </div>
      </div>
      <div className="mt-6 flex justify-end space-x-2">
        <Button type="button" variant="secondary" onClick={onCancel}>Cancel</Button>
        <Button type="submit">Submit Complaint</Button>
      </div>
    </form>
  );
};

export default AddComplaintForm;
