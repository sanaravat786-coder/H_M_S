import React, { useState } from 'react';
import { Button } from './ui/Button';
import { Input } from './ui/Input';
import { Select } from './ui/Select';

const RecordPaymentForm = ({ onSave, onCancel, fee }) => {
  const [amount, setAmount] = useState('');
  const [paymentMethod, setPaymentMethod] = useState('Card');

  const handleSubmit = (e) => {
    e.preventDefault();
    onSave({ 
        p_fee_id: fee.id,
        p_amount: parseFloat(amount),
        p_payment_method: paymentMethod
    });
  };

  return (
    <form onSubmit={handleSubmit}>
        <p className="mb-4 text-muted-foreground">Recording payment for Invoice <span className="font-semibold text-card-foreground">{fee.id}</span> for student <span className="font-semibold text-card-foreground">{fee.students.name}</span>.</p>
      <div className="space-y-4">
        <div>
          <label className="text-sm font-medium text-muted-foreground">Amount (£)</label>
          <Input type="number" step="0.01" placeholder="e.g., 500.00" className="mt-1" value={amount} onChange={e => setAmount(e.target.value)} required />
        </div>
        <div>
          <label className="text-sm font-medium text-muted-foreground">Payment Method</label>
          <Select className="mt-1" value={paymentMethod} onChange={e => setPaymentMethod(e.target.value)}>
            <option>Card</option>
            <option>Bank Transfer</option>
            <option>Cash</option>
          </Select>
        </div>
      </div>
      <div className="mt-6 flex justify-end space-x-2">
        <Button type="button" variant="secondary" onClick={onCancel}>Cancel</Button>
        <Button type="submit">Record Payment</Button>
      </div>
    </form>
  );
};

export default RecordPaymentForm;
