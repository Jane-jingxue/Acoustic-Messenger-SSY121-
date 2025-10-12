clc; clear; close all;

%% Test 1: Generate test message
fprintf('=== Test 1: Generating Test Message ===\n');

% Create a 432-bit test message (random bits)
test_bits = randi([0 1], 1, 432);
fprintf('Generated %d random bits\n\n', length(test_bits));

%% Test 2: Build complete transmitter signal for analysis
fprintf('=== Test 2: Building Transmitter Signal ===\n');

% System parameters
fs = 16000;
Rs = 200;
sps = fs/Rs;
alpha = 0.20;
span = 8;
fc_A = 2000; % Carrier frequency for PC A
fc_B = 5000; % Carrier frequency for PC B

% QPSK constellation (Gray)
const = [1+1j, -1+1j, 1-1j, -1-1j] / sqrt(2);

% Bit to symbol mapping
bpsymb = 2;
num_symbols = length(test_bits) / bpsymb;
m = reshape(test_bits, bpsymb, num_symbols)';
m_idx = bi2de(m, 'left-msb') + 1;
symbols = const(m_idx);

% Add preamble (Barker-13)
preamble_symbols = [1 1 1 1 1 -1 -1 1 1 -1 1 -1 1];
preamble_symbols = (preamble_symbols + 1j*preamble_symbols) / sqrt(2);
tx_symbols = [preamble_symbols, symbols];

% Upsample
x_upsample = upsample(tx_symbols, sps);

% Root Raised Cosine pulse shaping
Tsymb = 1/Rs;
[pulse, t_pulse] = rtrcpuls(alpha, Tsymb, fs, span);

% Apply pulse shaping
s_baseband = conv(x_upsample, pulse);

% Remove transient
delay = span * sps;
s_baseband_trimmed = s_baseband(delay+1:end-delay);

% Upconvert to both carriers
t = (0:length(s_baseband_trimmed)-1) / fs;
s_passband_A = real(s_baseband_trimmed .* exp(1j*2*pi*fc_A*t));
s_passband_B = real(s_baseband_trimmed .* exp(1j*2*pi*fc_B*t));

% Normalize
s_passband_A = s_passband_A / max(abs(s_passband_A)) * 0.9;
s_passband_B = s_passband_B / max(abs(s_passband_B)) * 0.9;

fprintf('Signal generation complete\n');
fprintf('Total symbols: %d (including %d preamble)\n', length(tx_symbols), 13);
fprintf('Signal duration: %.3f seconds\n\n', length(s_passband_A)/fs);

%% Test 3: Visualize Pulse Shaping Filter
fprintf('=== Test 3: Pulse Shaping Filter ===\n');

figure('Name', 'Root Raised Cosine Pulse', 'Position', [50 50 1400 500]);

subplot(1,3,1);
plot(t_pulse*1000, pulse, 'b-', 'LineWidth', 2);
xlabel('Time (ms)');
ylabel('Amplitude');
title('RRC Pulse Shape (Time Domain)');
grid on;

subplot(1,3,2);
[H_pulse, f_pulse] = freqz(pulse, 1, 2048, fs);
plot(f_pulse, 20*log10(abs(H_pulse)), 'b-', 'LineWidth', 2);
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('RRC Frequency Response');
grid on;
xlim([0 1000]);

subplot(1,3,3);
plot(f_pulse, unwrap(angle(H_pulse))*180/pi, 'b-', 'LineWidth', 2);
xlabel('Frequency (Hz)');
ylabel('Phase (degrees)');
title('RRC Phase Response');
grid on;
xlim([0 1000]);

fprintf('Pulse shaping filter visualized\n\n');

%% Test 4: Baseband Signal Analysis
fprintf('=== Test 4: Baseband Signal Analysis ===\n');

figure('Name', 'Baseband Signal Analysis', 'Position', [100 100 1400 800]);

% Plot I and Q components
subplot(3,2,1);
t_baseband = (0:length(s_baseband)-1)/fs*1000; % in ms
plot(t_baseband, real(s_baseband), 'b-', 'LineWidth', 1);
xlabel('Time (ms)');
ylabel('Amplitude');
title('In-Phase (I) Component');
grid on;
xlim([0 50]); % Show first 50ms

subplot(3,2,2);
plot(t_baseband, imag(s_baseband), 'r-', 'LineWidth', 1);
xlabel('Time (ms)');
ylabel('Amplitude');
title('Quadrature (Q) Component');
grid on;
xlim([0 50]);

% Plot baseband constellation (before trimming transients)
samples_baseband = s_baseband(span*sps:sps:end-span*sps);
subplot(3,2,3);
plot(real(samples_baseband), imag(samples_baseband), 'b.', 'MarkerSize', 8);
hold on;
plot(real(const), imag(const), 'ro', 'MarkerSize', 12, 'LineWidth', 2);
grid on;
axis equal;
xlim([-1.5 1.5]);
ylim([-1.5 1.5]);
xlabel('In-Phase');
ylabel('Quadrature');
title('Baseband Constellation (Sampled)');
legend('Received', 'Ideal', 'Location', 'best');

% Plot baseband PSD
subplot(3,2,4);
[psd_bb, f_bb] = pwelch(s_baseband, [], [], 2048, fs, 'centered');
plot(f_bb, 10*log10(psd_bb), 'b-', 'LineWidth', 1.5);
xlabel('Frequency (Hz)');
ylabel('PSD (dB/Hz)');
title('Baseband Power Spectral Density');
grid on;
xlim([-1000 1000]);

% Eye diagram for I component
subplot(3,2,5);
% Extract data portion (after preamble)
preamble_len = 13;
data_start_idx = (preamble_len + span) * sps + 1;
data_signal_I = real(s_baseband(data_start_idx:end-span*sps));
eyediagram(data_signal_I(1:min(50*sps, length(data_signal_I))), sps);
title('Eye Diagram - In-Phase');

% Eye diagram for Q component
subplot(3,2,6);
data_signal_Q = imag(s_baseband(data_start_idx:end-span*sps));
eyediagram(data_signal_Q(1:min(50*sps, length(data_signal_Q))), sps);
title('Eye Diagram - Quadrature');

fprintf('Baseband analysis complete\n\n');

%% Test 5: Passband Signal Analysis (PC A - 2 kHz)
fprintf('=== Test 5: Passband Signal (PC A, fc = %d Hz) ===\n', fc_A);

figure('Name', 'PC A Passband Signal', 'Position', [150 150 1400 800]);

% Time domain signal
subplot(3,2,1);
t_pass = (0:length(s_passband_A)-1)/fs*1000;
plot(t_pass, s_passband_A, 'b-', 'LineWidth', 1);
xlabel('Time (ms)');
ylabel('Amplitude');
title(sprintf('TX Signal Time Domain (fc = %d Hz)', fc_A));
grid on;
xlim([0 20]); % Show first 20ms

% Zoomed time domain
subplot(3,2,2);
zoom_samples = 200;
plot(t_pass(1:zoom_samples), s_passband_A(1:zoom_samples), 'b-', 'LineWidth', 1.5);
xlabel('Time (ms)');
ylabel('Amplitude');
title('TX Signal (Zoomed)');
grid on;

% Power Spectral Density
subplot(3,2,3);
[psd_A, f_A] = pwelch(s_passband_A, hamming(512), 256, 2048, fs);
plot(f_A, 10*log10(psd_A), 'b-', 'LineWidth', 1.5);
hold on;
yl = ylim;
plot([fc_A, fc_A], yl, 'r--', 'LineWidth', 2);
text(fc_A, yl(2), ' Carrier', 'Color', 'r', 'VerticalAlignment', 'top');
plot([fc_A-240, fc_A-240], yl, 'g--', 'LineWidth', 1);
text(fc_A-240, yl(2), ' -240 Hz', 'Color', 'g', 'VerticalAlignment', 'top');

plot([fc_A+240, fc_A+240], yl, 'g--', 'LineWidth', 1);
text(fc_A+240, yl(2), ' +240 Hz', 'Color', 'g', 'VerticalAlignment', 'top');
xlabel('Frequency (Hz)');
ylabel('PSD (dB/Hz)');
title('Power Spectral Density');
grid on;
xlim([fc_A-600, fc_A+600]);

% Normalized PSD (for mask compliance)
subplot(3,2,4);
psd_A_norm = psd_A / max(psd_A);
plot(f_A - fc_A, 10*log10(psd_A_norm), 'b-', 'LineWidth', 1.5);
hold on;
% Draw spectral mask (red mask from RFP)
mask_f = [-300 -240 -200 -150 -120 0 120 150 200 240 300];
mask_p = [-40 -40 -35 -30 -25 0 -25 -30 -35 -40 -40];
plot(mask_f, mask_p, 'r--', 'LineWidth', 2);
xlabel('Frequency offset from carrier (Hz)');
ylabel('Normalized Power (dB)');
title('Spectral Mask Compliance');
legend('TX Signal', 'Red Mask', 'Location', 'best');
grid on;
xlim([-400 400]);
ylim([-50 5]);

% Spectrogram
subplot(3,2,[5 6]);
spectrogram(s_passband_A, hamming(256), 128, 512, fs, 'yaxis');
title('Spectrogram');
ylim([0 8]);

fprintf('PC A passband analysis complete\n\n');

%% Test 6: Passband Signal Analysis (PC B - 5 kHz)
fprintf('=== Test 6: Passband Signal (PC B, fc = %d Hz) ===\n', fc_B);

figure('Name', 'PC B Passband Signal', 'Position', [200 200 1400 800]);

% Time domain signal
subplot(3,2,1);
plot(t_pass, s_passband_B, 'b-', 'LineWidth', 1);
xlabel('Time (ms)');
ylabel('Amplitude');
title(sprintf('TX Signal Time Domain (fc = %d Hz)', fc_B));
grid on;
xlim([0 20]);

% Zoomed time domain
subplot(3,2,2);
plot(t_pass(1:zoom_samples), s_passband_B(1:zoom_samples), 'b-', 'LineWidth', 1.5);
xlabel('Time (ms)');
ylabel('Amplitude');
title('TX Signal (Zoomed)');
grid on;

% Power Spectral Density
subplot(3,2,3);
[psd_B, f_B] = pwelch(s_passband_B, hamming(512), 256, 2048, fs);
plot(f_B, 10*log10(psd_B), 'b-', 'LineWidth', 1.5);
hold on;
yl = ylim;
plot([fc_B, fc_B], yl, 'r--', 'LineWidth', 2);
text(fc_B, yl(2), ' Carrier', 'Color', 'r', 'VerticalAlignment', 'top');

plot([fc_B-240, fc_B-240], yl, 'g--', 'LineWidth', 1);
text(fc_B-240, yl(2), ' -240 Hz', 'Color', 'g', 'VerticalAlignment', 'top');

plot([fc_B+240, fc_B+240], yl, 'g--', 'LineWidth', 1);
text(fc_B+240, yl(2), ' +240 Hz', 'Color', 'g', 'VerticalAlignment', 'top');
xlabel('Frequency (Hz)');
ylabel('PSD (dB/Hz)');
title('Power Spectral Density');
grid on;
xlim([fc_B-600, fc_B+600]);

% Normalized PSD
subplot(3,2,4);
psd_B_norm = psd_B / max(psd_B);
plot(f_B - fc_B, 10*log10(psd_B_norm), 'b-', 'LineWidth', 1.5);
hold on;
plot(mask_f, mask_p, 'r--', 'LineWidth', 2);
xlabel('Frequency offset from carrier (Hz)');
ylabel('Normalized Power (dB)');
title('Spectral Mask Compliance');
legend('TX Signal', 'Red Mask', 'Location', 'best');
grid on;
xlim([-400 400]);
ylim([-50 5]);

% Spectrogram
subplot(3,2,[5 6]);
spectrogram(s_passband_B, hamming(256), 128, 512, fs, 'yaxis');
title('Spectrogram');
ylim([0 8]);

fprintf('PC B passband analysis complete\n\n');

%% Test 7: Bandwidth and Spectral Mask Compliance
fprintf('=== Test 7: Bandwidth Measurement ===\n');

% Calculate occupied bandwidth at different levels
psd_A_norm = psd_A / max(psd_A);
idx_3dB = find(psd_A_norm > 0.5); % -3dB points
idx_20dB = find(psd_A_norm > 0.01); % -20dB points
idx_40dB = find(psd_A_norm > 0.0001); % -40dB points

BW_3dB = f_A(idx_3dB(end)) - f_A(idx_3dB(1));
BW_20dB = f_A(idx_20dB(end)) - f_A(idx_20dB(1));
BW_40dB = f_A(idx_40dB(end)) - f_A(idx_40dB(1));

fprintf('PC A Bandwidth measurements:\n');
fprintf('  -3dB bandwidth:  %.2f Hz\n', BW_3dB);
fprintf('  -20dB bandwidth: %.2f Hz\n', BW_20dB);
fprintf('  -40dB bandwidth: %.2f Hz\n', BW_40dB);
fprintf('  Theoretical (1+α)Rs: %.2f Hz\n', (1+alpha)*Rs);

% Check spectral mask compliance at key points
mask_points = [-300 -240 -150 -120 120 150 240 300];
fprintf('\nSpectral mask compliance check:\n');
for mp = mask_points
    f_idx = find(abs((f_A - fc_A) - mp) < 1, 1);
    if ~isempty(f_idx)
        power_at_point = 10*log10(psd_A_norm(f_idx));
        fprintf('  At %+4d Hz: %.1f dB', mp, power_at_point);
        if abs(mp) == 300 && power_at_point < -40
            fprintf(' ✓\n');
        elseif abs(mp) == 240 && power_at_point < -40
            fprintf(' ✓\n');
        elseif abs(mp) == 150 && power_at_point < -30
            fprintf(' ✓\n');
        elseif abs(mp) == 120 && power_at_point < -25
            fprintf(' ✓\n');
        else
            fprintf('\n');
        end
    end
end

fprintf('\n');

%% Test 8: Performance Metrics Summary
fprintf('=== Test 8: Performance Summary ===\n');

signal_duration = length(s_passband_A) / fs;
data_rate = 432 / signal_duration;
RTT_estimate = signal_duration * 2;

fprintf('Transmission Parameters:\n');
fprintf('  Symbol rate: %d symbols/s\n', Rs);
fprintf('  Modulation: QPSK (%d bits/symbol)\n', bpsymb);
fprintf('  Roll-off factor: %.2f\n', alpha);
fprintf('  Samples per symbol: %d\n', sps);
fprintf('  Carrier frequencies: %d Hz, %d Hz\n', fc_A, fc_B);
fprintf('\nPerformance Metrics:\n');
fprintf('  Signal duration: %.3f s\n', signal_duration);
fprintf('  Data rate: %.2f bits/s\n', data_rate);
fprintf('  Spectral efficiency: %.2f bits/s/Hz\n', Rs*bpsymb / BW_20dB);
fprintf('  Estimated RTT (half-duplex): %.2f s\n', RTT_estimate);

if RTT_estimate < 6
    fprintf('  ✓ RTT requirement met (<6s)\n');
    if RTT_estimate < 5
        fprintf('  ✓ Extra point: RTT <5s\n');
    end
    if RTT_estimate < 4.5
        fprintf('  ✓ Extra points: RTT <4.5s\n');
    end
end

fprintf('\n=== All Visualizations Complete ===\n');
fprintf('Total figures generated: 5\n');