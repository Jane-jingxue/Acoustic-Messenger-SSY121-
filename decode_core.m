function a_hat = decode_core(s_rx, fc)
% DECODE_CORE: 接收机核心解码函数 (用于理想环回测试)
%   输入: s_rx - 发射机发送的实数带通信号
%         fc   - 载波频率
%   输出: a_hat - 解码出的原始比特序列

%% 1. 系统参数（必须与 transmitter.m 完美匹配！）
wc = 2*pi*fc;
B_max = 400; % LPF cut-off
fs = 16000;
% 【修正 1】：统一星座图顺序 (QPSK Gray coded)
const = [1+1j, -1+1j, 1-1j, -1-1j] / sqrt(2);
Rs = 200; % Symbol rate [symb/s]
Ts = 1/Rs; % Symbol time [s/symb]
alpha = 0.20;
fsfd = fs/Rs; % Samples per symbol (sps = 80)
span = 8;
[pulse, ~] = rtrcpuls(alpha,Ts,fs,span);
barker = [1,1,1,1,1,-1,-1,1,1,-1,1,-1,1];
D = 216; % Data Symbol number (432 bits / 2 bits/symb)
P = length(barker); % Preamble length in symbols (13)
bpsymb = 2; % Bits per symbol
Total_Symbols = P + D;
mf_delay = (length(pulse) - 1) / 2; % 匹配滤波器延迟 (320)

% 理想 Preamble 符号序列
preamble_symbols_ideal = (barker + 1i*barker) / sqrt(2);

fprintf('系统参数: fs=%d, Rs=%d, sps=%d, fc=%d\n', fs, Rs, fsfd, fc);

%% 2. 信号处理 (Downconversion and LPF)
s_rx = s_rx(:)'; % 确保输入为行向量
s_rx = s_rx./max(abs(s_rx)); % 归一化幅度
t = (0:length(s_rx)-1)/fs;

% 下变频 (Baseband Conversion)
s_baseband = s_rx .* sqrt(2) .* exp(-1j*wc*t);

% 低通滤波 (LPF)
I_filt = lowpass(real(s_baseband), B_max, fs);
Q_filt = lowpass(imag(s_baseband), B_max, fs);
S = I_filt + 1i*Q_filt;

%% 3. 同步: 匹配滤波 (MF) 和相关性 (Synchronization: MF and Correlation)

% 匹配滤波 (MF)
S_mf = conv(S, fliplr(conj(pulse))); % 使用 conv 函数实现匹配滤波

% 生成 RRC 滤波后的理想 Preamble 信号用于相关性检测
preamble_symbols_upsample = upsample(preamble_symbols_ideal, fsfd);
PA_train = conv(preamble_symbols_upsample, pulse); % 理想 RRC 脉冲成形后的前导码序列

% 互相关 (Cross-correlation)
corr_result = conv(S_mf, fliplr(conj(PA_train))); 
[peak, idx] = max(abs(corr_result)); % 寻找相关峰 (idx = 2643)

% 【重要日志】
L_PA = length(PA_train); % 1680
fprintf('相关峰值: %.4f at %d\n', peak, idx);


%% 4. 符号抽取 (Sampling) - 【关键修正】

% 1. 计算【理论上】的第一个 Preamble 符号的中心位置 k_first_measured 
% k_first_measured = idx - (L_PA - 1) - (P - 1) * fsfd
k_first_preamble_center_measured = round(idx - (L_PA - 1) - (P - 1) * fsfd); 

% 2. 提取【时钟相位偏移】(Offset)
% k_first_preamble_center_measured=4，这定义了正确的时钟相位
timing_offset_phase = mod(k_first_preamble_center_measured - 1, fsfd) + 1; % mod(4-1, 80) + 1 = 4

% 3. 确定【实际】的第一个符号的中心位置 (基于理论延迟和测量的相位)
% 理论最小起始点：mf_delay + 1 = 321
start_index_theory = mf_delay + 1; % 321

% 寻找 >= start_index_theory 且 mod(start_index - 1, fsfd) = timing_offset_phase - 1 的点。
current_phase = mod(start_index_theory - 1, fsfd) + 1; % mod(321-1, 80)+1 = 1
phase_difference = mod(timing_offset_phase - current_phase, fsfd); % mod(4 - 1, 80) = 3
start_index = start_index_theory + phase_difference; % 321 + 3 = 324

fprintf('时钟相位偏移: %d, 理论起始点: %d, 修正后的符号起始位置: %d\n', ...
    timing_offset_phase, start_index_theory, start_index);


% 抽取所有 Preamble + Data 符号的索引
data_ind_all = start_index : fsfd : start_index + (Total_Symbols - 1) * fsfd;

% 安全检查
data_ind_all = data_ind_all(data_ind_all > 0 & data_ind_all <= length(S_mf));
data_ind_all = round(data_ind_all);

rx_vec = S_mf(data_ind_all); 
rx_vec = rx_vec / mean(abs(rx_vec)); % 归一化幅度

if length(rx_vec) < Total_Symbols
    warning('警告: 抽取到的符号数量不足，请检查同步逻辑。');
    Total_Symbols_Actual = length(rx_vec);
else
    Total_Symbols_Actual = Total_Symbols;
end

% 分离 Preamble 和 Data 符号
preamble_received = rx_vec(1:min(P, Total_Symbols_Actual));
data_symbols_received = rx_vec(min(P, Total_Symbols_Actual)+1:Total_Symbols_Actual);


%% 5. 相位估计与补偿 (Phase Estimation and Compensation)

if length(preamble_received) == P
    % 1. 粗略相位估计 (用于计算基准相偏)
    phase_errors = angle(preamble_received .* conj(preamble_symbols_ideal));
    avg_phase_error = mean(phase_errors);

    % 2. 消除 90/180/270 度模糊
    possible_rotations = [0, 90, 180, 270];
    min_error = inf;
    best_rotation = 0;
    
    % 将接收到的Preamble校正到平均相位，然后检查与理想Preamble的匹配程度
    preamble_ref = preamble_received * exp(-1j * avg_phase_error); 

    for rotation = possible_rotations
        rotated_ideal = preamble_symbols_ideal * exp(1j * rotation * pi/180); 
        error = mean(abs(preamble_ref - rotated_ideal).^2);
        
        if error < min_error
            min_error = error;
            best_rotation = rotation;
        end
    end
    
    compensated_phi_rad = avg_phase_error + best_rotation * pi/180;
    fprintf('相位估计: %.2f 度, 模糊修正: %d 度, 总补偿: %.2f 度\n', ...
            avg_phase_error * 180/pi, best_rotation, compensated_phi_rad * 180/pi);
    
    % 应用于数据符号
    data_symbols_compensated = data_symbols_received * exp(-1j * compensated_phi_rad);
else
    warning('警告: Preamble 符号数不足，跳过相位补偿。');
    data_symbols_compensated = data_symbols_received;
end


%% 6. 判决和比特恢复 (Decision and Bit Recovery)

% 最小距离检测 (Minimum Distance Detector)
metric = abs(repmat(data_symbols_compensated.', 1, 4) - repmat(const, length(data_symbols_compensated), 1)).^2;
[~, m_hat_idx] = min(metric, [], 2);
m_hat_idx = m_hat_idx' - 1; % 符号索引 (0, 1, 2, 3)

% 转换为比特 (Gray code)
bit_pairs = de2bi(m_hat_idx, bpsymb, 'left-msb');

% 展平为最终的比特序列
a_hat = reshape(bit_pairs.', 1, []);

end