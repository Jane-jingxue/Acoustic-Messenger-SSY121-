<<<<<<< HEAD
function a_hat = decode_core_debug(s_rx, fc, X_orig)
% 深度调试版本

%% 参数设置
wc = 2*pi*fc;
B_max = 400;
fs = 16000;
const = [1+1j, -1+1j, 1-1j, -1-1j] / sqrt(2);
Rs = 200;
Ts = 1/Rs;
alpha = 0.20;
fsfd = fs/Rs;
span = 8;
[pulse, ~] = rtrcpuls(alpha, Ts, fs, span);
barker = [1,1,1,1,1,-1,-1,1,1,-1,1,-1,1];
D = 216;
P = length(barker);
bpsymb = 2;

fprintf('系统参数: fs=%d, Rs=%d, sps=%d, fc=%d\n', fs, Rs, fsfd, fc);

%% 信号预处理
s_rx = s_rx(:)'; % 确保行向量
s_rx = s_rx / max(abs(s_rx));

% 下变频
t = (0:length(s_rx)-1)/fs;
s_baseband = s_rx .* exp(-1j*wc*t) * sqrt(2);

% LPF
I_filt = lowpass(real(s_baseband), B_max, fs);
Q_filt = lowpass(imag(s_baseband), B_max, fs);
S = I_filt + 1i*Q_filt;

fprintf('下变频后信号长度: %d\n', length(S));

%% 前导码检测
PA = barker + 1i*barker;
PA_upsampled = upsample(PA, fsfd);
PA_train = conv(PA_upsampled, pulse);
PA_train = PA_train / norm(PA_train); % 归一化

corr = matched_filter(S, PA_train);
[peak, idx] = max(abs(corr));

fprintf('前导码检测: 峰值=%.4f, 位置=%d\n', peak, idx);

% 绘制相关结果
figure(2);
plot(abs(corr)); title('前导码相关结果'); xlabel('采样点'); ylabel('相关值');
hold on; plot(idx, peak, 'ro', 'MarkerSize', 10); hold off;

%% 符号同步和抽取
% 计算精确的起始位置
mf_delay = (length(pulse) - 1) / 2;
preamble_length = length(PA_train);

% 关键修正：基于相关峰的精确定时
start_index = idx - preamble_length + 1 + mf_delay;
start_index = round(start_index);

fprintf('匹配滤波器延迟: %d\n', mf_delay);
fprintf('前导码训练序列长度: %d\n', preamble_length);
fprintf('计算起始位置: %d\n', start_index);

% 匹配滤波
S_mf = matched_filter(S, pulse);

% 符号抽取 - 抽取所有符号 (前导码 + 数据)
total_symbols_needed = P + D;
data_ind = start_index : fsfd : start_index + (total_symbols_needed-1)*fsfd;

% 边界检查
if data_ind(end) > length(S_mf)
    available = floor((length(S_mf) - start_index) / fsfd);
    fprintf('警告: 需要%d符号但只能抽取%d符号\n', total_symbols_needed, available);
    data_ind = start_index : fsfd : start_index + (available-1)*fsfd;
end

rx_vec = S_mf(round(data_ind));
fprintf('实际抽取符号数: %d\n', length(rx_vec));

% 绘制星座图
figure(3);
plot(real(rx_vec), imag(rx_vec), 'o'); grid on;
title('接收符号星座图'); xlabel('I'); ylabel('Q');
axis equal;

%% 相位估计和补偿
% 使用前导码进行精确相位估计
preamble_received = rx_vec(1:P);
preamble_ideal = PA; % 理想前导码

% 计算平均相位误差
phase_errors = angle(preamble_received .* conj(preamble_ideal));
avg_phase_error = mean(phase_errors);
phi_hat_rad = avg_phase_error;
phi_hat_deg = phi_hat_rad * 180/pi;

fprintf('相位估计: %.2f 度 (%.4f 弧度)\n', phi_hat_deg, phi_hat_rad);

% 相位补偿
rx_vec_compensated = rx_vec * exp(-1j * phi_hat_rad);

% 绘制补偿后的星座图
figure(4);
plot(real(rx_vec_compensated), imag(rx_vec_compensated), 'o'); grid on;
title('相位补偿后星座图'); xlabel('I'); ylabel('Q');
axis equal;

%% 符号到比特的映射
if length(rx_vec_compensated) < P
    fprintf('错误: 符号数不足\n');
    a_hat = [];
    return;
end

% 提取数据符号 (跳过前导码)
data_symbols = rx_vec_compensated(P+1:end);

% 最小距离检测
metric = abs(repmat(data_symbols.', 1, 4) - repmat(const, length(data_symbols), 1)).^2;
[~, symbol_indices] = min(metric, [], 2);
symbol_indices = symbol_indices' - 1;

% 转换为比特
bit_pairs = de2bi(symbol_indices, 2, 'left-msb')';
a_hat = bit_pairs(:)';

% 裁剪到正确长度
if length(a_hat) > 432
    a_hat = a_hat(1:432);
elseif length(a_hat) < 432
    fprintf('警告: 恢复比特数不足 (%d < 432)\n', length(a_hat));
    % 补零
    a_hat = [a_hat, zeros(1, 432 - length(a_hat))];
end

fprintf('恢复比特数: %d\n', length(a_hat));

%% 验证前几个符号
if length(rx_vec) >= 5
    fprintf('\n前5个接收符号验证:\n');
    for i = 1:min(5, length(data_symbols))
        [~, detected_idx] = min(abs(data_symbols(i) - const));
        fprintf('符号%d: 接收=(%.3f%+.3fi), 检测=索引%d\n', ...
            i, real(data_symbols(i)), imag(data_symbols(i)), detected_idx);
    end
end

=======
function a_hat = decode_core_debug(s_rx, fc, X_orig)
% 深度调试版本

%% 参数设置
wc = 2*pi*fc;
B_max = 400;
fs = 16000;
const = [1+1j, -1+1j, 1-1j, -1-1j] / sqrt(2);
Rs = 200;
Ts = 1/Rs;
alpha = 0.20;
fsfd = fs/Rs;
span = 8;
[pulse, ~] = rtrcpuls(alpha, Ts, fs, span);
barker = [1,1,1,1,1,-1,-1,1,1,-1,1,-1,1];
D = 216;
P = length(barker);
bpsymb = 2;

fprintf('系统参数: fs=%d, Rs=%d, sps=%d, fc=%d\n', fs, Rs, fsfd, fc);

%% 信号预处理
s_rx = s_rx(:)'; % 确保行向量
s_rx = s_rx / max(abs(s_rx));

% 下变频
t = (0:length(s_rx)-1)/fs;
s_baseband = s_rx .* exp(-1j*wc*t) * sqrt(2);

% LPF
I_filt = lowpass(real(s_baseband), B_max, fs);
Q_filt = lowpass(imag(s_baseband), B_max, fs);
S = I_filt + 1i*Q_filt;

fprintf('下变频后信号长度: %d\n', length(S));

%% 前导码检测
PA = barker + 1i*barker;
PA_upsampled = upsample(PA, fsfd);
PA_train = conv(PA_upsampled, pulse);
PA_train = PA_train / norm(PA_train); % 归一化

corr = matched_filter(S, PA_train);
[peak, idx] = max(abs(corr));

fprintf('前导码检测: 峰值=%.4f, 位置=%d\n', peak, idx);

% 绘制相关结果
figure(2);
plot(abs(corr)); title('前导码相关结果'); xlabel('采样点'); ylabel('相关值');
hold on; plot(idx, peak, 'ro', 'MarkerSize', 10); hold off;

%% 符号同步和抽取
% 计算精确的起始位置
mf_delay = (length(pulse) - 1) / 2;
preamble_length = length(PA_train);

% 关键修正：基于相关峰的精确定时
start_index = idx - preamble_length + 1 + mf_delay;
start_index = round(start_index);

fprintf('匹配滤波器延迟: %d\n', mf_delay);
fprintf('前导码训练序列长度: %d\n', preamble_length);
fprintf('计算起始位置: %d\n', start_index);

% 匹配滤波
S_mf = matched_filter(S, pulse);

% 符号抽取 - 抽取所有符号 (前导码 + 数据)
total_symbols_needed = P + D;
data_ind = start_index : fsfd : start_index + (total_symbols_needed-1)*fsfd;

% 边界检查
if data_ind(end) > length(S_mf)
    available = floor((length(S_mf) - start_index) / fsfd);
    fprintf('警告: 需要%d符号但只能抽取%d符号\n', total_symbols_needed, available);
    data_ind = start_index : fsfd : start_index + (available-1)*fsfd;
end

rx_vec = S_mf(round(data_ind));
fprintf('实际抽取符号数: %d\n', length(rx_vec));

% 绘制星座图
figure(3);
plot(real(rx_vec), imag(rx_vec), 'o'); grid on;
title('接收符号星座图'); xlabel('I'); ylabel('Q');
axis equal;

%% 相位估计和补偿
% 使用前导码进行精确相位估计
preamble_received = rx_vec(1:P);
preamble_ideal = PA; % 理想前导码

% 计算平均相位误差
phase_errors = angle(preamble_received .* conj(preamble_ideal));
avg_phase_error = mean(phase_errors);
phi_hat_rad = avg_phase_error;
phi_hat_deg = phi_hat_rad * 180/pi;

fprintf('相位估计: %.2f 度 (%.4f 弧度)\n', phi_hat_deg, phi_hat_rad);

% 相位补偿
rx_vec_compensated = rx_vec * exp(-1j * phi_hat_rad);

% 绘制补偿后的星座图
figure(4);
plot(real(rx_vec_compensated), imag(rx_vec_compensated), 'o'); grid on;
title('相位补偿后星座图'); xlabel('I'); ylabel('Q');
axis equal;

%% 符号到比特的映射
if length(rx_vec_compensated) < P
    fprintf('错误: 符号数不足\n');
    a_hat = [];
    return;
end

% 提取数据符号 (跳过前导码)
data_symbols = rx_vec_compensated(P+1:end);

% 最小距离检测
metric = abs(repmat(data_symbols.', 1, 4) - repmat(const, length(data_symbols), 1)).^2;
[~, symbol_indices] = min(metric, [], 2);
symbol_indices = symbol_indices' - 1;

% 转换为比特
bit_pairs = de2bi(symbol_indices, 2, 'left-msb')';
a_hat = bit_pairs(:)';

% 裁剪到正确长度
if length(a_hat) > 432
    a_hat = a_hat(1:432);
elseif length(a_hat) < 432
    fprintf('警告: 恢复比特数不足 (%d < 432)\n', length(a_hat));
    % 补零
    a_hat = [a_hat, zeros(1, 432 - length(a_hat))];
end

fprintf('恢复比特数: %d\n', length(a_hat));

%% 验证前几个符号
if length(rx_vec) >= 5
    fprintf('\n前5个接收符号验证:\n');
    for i = 1:min(5, length(data_symbols))
        [~, detected_idx] = min(abs(data_symbols(i) - const));
        fprintf('符号%d: 接收=(%.3f%+.3fi), 检测=索引%d\n', ...
            i, real(data_symbols(i)), imag(data_symbols(i)), detected_idx);
    end
end

>>>>>>> 230df9110b2bad0e8544304983446d036875369b
end