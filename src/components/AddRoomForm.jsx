import React, { useState } from 'react';
import { Button } from './ui/Button';
import { Input } from './ui/Input';
import { Select } from './ui/Select';

const AddRoomForm = ({ onSave, onCancel }) => {
  const [roomNo, setRoomNo] = useState('');
  const [block, setBlock] = useState('A');
  const [type, setType] = useState('Single');
  const [capacity, setCapacity] = useState(1);

  const handleSubmit = (e) => {
    e.preventDefault();
    onSave({ 
        p_room_no: roomNo,
        p_block: block,
        p_type: type,
        p_capacity: capacity
    });
  };

  return (
    <form onSubmit={handleSubmit}>
      <div className="space-y-4">
        <div>
          <label className="text-sm font-medium text-muted-foreground">Room Number</label>
          <Input placeholder="e.g., 101" className="mt-1" value={roomNo} onChange={e => setRoomNo(e.target.value)} required />
        </div>
        <div>
          <label className="text-sm font-medium text-muted-foreground">Block</label>
          <Select className="mt-1" value={block} onChange={e => setBlock(e.target.value)}>
            <option>A</option>
            <option>B</option>
            <option>C</option>
            <option>D</option>
          </Select>
        </div>
        <div>
          <label className="text-sm font-medium text-muted-foreground">Room Type</label>
          <Select className="mt-1" value={type} onChange={e => setType(e.target.value)}>
            <option>Single</option>
            <option>Double</option>
            <option>Triple</option>
          </Select>
        </div>
        <div>
          <label className="text-sm font-medium text-muted-foreground">Capacity</label>
          <Input type="number" min="1" max="10" className="mt-1" value={capacity} onChange={e => setCapacity(parseInt(e.target.value))} required />
        </div>
      </div>
      <div className="mt-6 flex justify-end space-x-2">
        <Button type="button" variant="secondary" onClick={onCancel}>Cancel</Button>
        <Button type="submit">Save Room</Button>
      </div>
    </form>
  );
};

export default AddRoomForm;
