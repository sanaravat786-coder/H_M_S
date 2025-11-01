import React from 'react';
import { cn } from '../../lib/utils';
import { Loader } from 'lucide-react';

const spinnerVariants = {
  size: {
    default: 'h-6 w-6',
    sm: 'h-4 w-4',
    lg: 'h-10 w-10',
  },
};

const Spinner = ({ size = 'default' }) => {
  return (
    <Loader className={cn('animate-spin text-accent', spinnerVariants.size[size])} />
  );
};

export default Spinner;
