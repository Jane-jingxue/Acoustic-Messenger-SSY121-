function [s_passband] = transmitter(X, fc)
% Acoustic messenger transmitter function
% Inputs:
%    X  - Row vector of 432 bits (0 or 1)
%    fc - Carrier frequency (Hz)

% System parameters
fs = 16000; Rs = 200; sps = fs/Rs;
alpha = 0.20; span = 8;

% Validate input
if length(X) ~= 432
    error('Input X must be a 432-bit vector');
end

% QPSK constellation (Gray coded)
const = [1+1j, -1+1j, 1-1j, -1-1j] / sqrt(2);

% Bit to symbol mapping
bpsymb = 2;
num_symbols = length(X) / bpsymb;
m = reshape(X, bpsymb, num_symbols)';
m_idx = bi2de(m, 'left-msb') + 1;

% === 添加映射验证 ===
fprintf('=== 发射机映射验证 ===\n');
fprintf('前10个比特对映射:\n');
for i = 1:min(10, size(m,1))
    bits = m(i,:);
    symbol_idx = m_idx(i);
    fprintf('符号%d: 比特[%d%d] -> 索引%d -> 星座(%.3f%+.3fi)\n', ...
        i, bits(1), bits(2), symbol_idx, real(const(symbol_idx)), imag(const(symbol_idx)));
end

% 统计符号分布
fprintf('符号索引分布: ');
for i = 1:4
    count = sum(m_idx == i);
    fprintf('索引%d:%d个 ', i, count);
end
fprintf('\n');

symbols = const(m_idx);

% 其余代码保持不变...
preamble_bits = [1 1 1 1 1 -1 -1 1 1 -1 1 -1 1];
preamble_symbols = (preamble_bits + 1j*preamble_bits) / sqrt(2);

tx_symbols = [preamble_symbols, symbols];
x_upsample = upsample(tx_symbols, sps);
Tsymb = 1/Rs;
[pulse, ~] = rtrcpuls(alpha, Tsymb, fs, span);

delay = (span * sps) / 2;
s_baseband = conv(x_upsample, pulse);
s_baseband = s_baseband(delay + 1 : end - delay);

t = (0:length(s_baseband)-1) / fs;
s_passband = real(s_baseband .* exp(1j*2*pi*fc*t));
s_passband = s_passband / max(abs(s_passband)) * 0.9;

fprintf('发射完成: %d符号, 信号长度=%d\n', num_symbols, length(s_passband));
end