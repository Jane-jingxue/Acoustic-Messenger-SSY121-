function transmitter(X, fc)
% Acoustic messenger transmitter function
% Inputs:
%   X  - Row vector of 432 bits (0 or 1)
%   fc - Carrier frequency (Hz)
%
% This function transmits the bit stream X over an acoustic channel
% using QPSK modulation with root raised cosine pulse shaping

% System parameters (from proposal)
fs = 16000;              % Sampling frequency (Hz)
Rs = 200;                % Symbol rate (symbols/s)
sps = fs/Rs;                % Samples per symbol (fs/Rs)
alpha = 0.20;            % Roll-off factor for RRC (adjusted for 240 Hz BW)
span = 8;                % Filter span in symbols (increased for sharper filtering)

% Validate input
if length(X) ~= 432
    error('Input X must be a 432-bit vector');
end
if ~all(X == 0 | X == 1)
    error('Input X must contain only 0s and 1s');
end

% QPSK constellation (Gray coded)
% Maps 2 bits to one symbol
const = [1+1j, -1+1j, 1-1j, -1-1j] / sqrt(2);

% Bit to symbol mapping
bpsymb = 2;                              % Bits per symbol for QPSK
num_symbols = length(X) / bpsymb;        % Number of symbols
m = reshape(X, bpsymb, num_symbols)';    % Group bits into pairs
m_idx = bi2de(m, 'left-msb') + 1;        % Convert to symbol indices (1-4)
symbols = const(m_idx);                  % Map to QPSK symbols

% Create preamble for synchronization (Barker-13 code)
preamble_bits = [1 1 1 1 1 -1 -1 1 1 -1 1 -1 1];
preamble_symbols = (preamble_bits + 1j*preamble_bits) / sqrt(2);

% Combine preamble and data symbols
tx_symbols = [preamble_symbols, symbols];

% Upsample symbols
x_upsample = upsample(tx_symbols, sps);

% Root Raised Cosine pulse shaping filter
Tsymb = 1/Rs;                            % Symbol time
[pulse, ~] = rtrcpuls(alpha, Tsymb, fs, span);

% Apply pulse shaping
s_baseband = conv(x_upsample, pulse);

% Remove transient effects 
delay = span * sps;
s_baseband = s_baseband(delay+1:end-delay);

% Upconvert to passband 
t = (0:length(s_baseband)-1) / fs;
s_passband = real(s_baseband .* exp(1j*2*pi*fc*t));

% Normalize to prevent clipping
s_passband = s_passband / max(abs(s_passband)) * 0.9;

% Transmit the signal
sound(s_passband, fs);

% Display transmission info
fprintf('Transmitting %d symbols (%d bits) at fc = %d Hz\n', ...
    num_symbols, length(X), fc);
fprintf('Symbol rate: %d symbols/s, Duration: %.2f s\n', ...
    Rs, length(s_passband)/fs);

end