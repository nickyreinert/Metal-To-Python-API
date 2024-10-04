import torch
import numpy as np
import ctypes
import time
import math
import time

if __name__ == "__main__":

    numItems = 1_000_000_000
    silent = True

    start_time = time.time()
    
    input_array = np.linspace(0, numItems - 1, numItems, dtype="float32")  # Sequential floats

    input_tensor = torch.tensor(input_array, device='mps', dtype=torch.float32)

    torch.mps.synchronize()
    
    output_tensor = torch.cos(input_tensor)

    torch.mps.synchronize()

    # Move the result back to CPU if needed
    output_array = output_tensor.cpu().numpy()

    end_time = time.time()
    computation_time = end_time - start_time
    
    # Check and print combined results
    combined_results = np.column_stack((input_array, output_array))
    if not silent:
        print("Input and Output (Cosine):")
        print(combined_results)
    
    print(f"Computation time: {computation_time:.6f} seconds; {numItems:,.0f} items")   