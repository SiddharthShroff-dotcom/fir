
def FIR_filter(inputs, weights):
    #we want to implement a FIR model that takes in inputs 
    # and calulcates a weighted sum of the inputs based on the FIR filter coefficients. 
    # The model will be able to process a sequence of input signals and produce an output signal.
    n_samples = len(inputs)
    j = 0
    #our output signal will be the same length as the input signal, 
    # so we will initialize it to be the same length as the input signal
    output_signal = [0] * n_samples
    for k in range(0,n_samples):
        j=0
        for i in range(k-len(weights)+1,k+1):
            if i >= 0:
                output_signal[k] = output_signal[k] + (inputs[i] * weights[len(weights)-1-j])
            j=j+1

    # Your main function implementation here
    return output_signal

print(FIR_filter([3, -2, 5, 1, 0, 4, -1, 2, 6, -3], [1, 2, 3, 4, 5, 6, 7, 8]))