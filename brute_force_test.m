% brute_force_test.m
% 目的：用穷举法遍历所有可能的符号起始位置，找出误码率（BER）为 0 的【最佳起始采样点】。
% 要求: 确保 transmitter.m, matched_filter.m, rtrcpuls.m 等函数文件在路径中。

%% 1. 系统参数和数据初始化 (必须与 decode_core/transmitter 保持一致)
clear; close all;

fs = 16000; Rs = 200; fc = 4000;
num_bits = 432; 
sps = fs/Rs; % Samples per symbol (80)

% 从 decode_core/transmitter 提取的参数
alpha = 0.20; span = 8; Ts = 1/Rs;
[pulse, ~] = rtrcpuls(alpha,Ts,fs,span); 
barker = [1,1,1,1,1,-1,-1,1,1,-1,1,-1,1];
P = length(barker); % Preamble symbols (13)
D = 216; % Data symbols (216)
Total_Symbols = P + D; % 229
mf_delay = (length(pulse) - 1) / 2; % 319 (RRC滤波器的群延迟)

% 星座图和理想前导码 (用于判决和相位同步)
const = [1+1j, -1+1j, 1-1j, -1-1j] / sqrt(2);
preamble_ideal = (barker + 1j*barker) / sqrt(2);

% 生成固定的随机输入比特 (用于计算 BER 的“真相”)
rng(1); % 固定随机种子，保证每次运行结果一致
X_orig = randi([0 1], 1, num_bits); 

fprintf('=== 信号起始位置穷举搜索模式 ===\n');
fprintf('目标符号数 (P+D): %d, 每符号采样点数 (sps): %d\n', Total_Symbols, sps);

%% 2. 运行接收机前半部分 (解调和匹配滤波)

% 生成信号
s_tx = transmitter(X_orig, fc); 

% --- 接收机前半部分 (解调, LPF, MF) ---
s_rx = s_tx(:).'; % 确保行向量
s_rx = s_rx./max(abs(s_rx));
wc = 2*pi*fc;
B_max = 400;
t = (0:length(s_rx)-1)/fs;
s_baseband = s_rx .* sqrt(2) .* exp(-1j*wc*t);
I_filt = lowpass(real(s_baseband), B_max, fs);
Q_filt = lowpass(imag(s_baseband), B_max, fs);
S = I_filt + 1i*Q_filt;
S_mf = matched_filter(S, pulse);

%% 3. 穷举法搜索最佳符号起始位置

% 理论起始点 (数据+前导码的第一个符号): start_index_theory = mf_delay + 1 = 320
% 搜索范围：在理论起始点附近，以 2*sps 为中心，上下浮动 5*sps 的范围
% 搜索范围应当覆盖所有可能性，通常一个符号周期(sps)内的偏移是合理的。
% 但为了安全，我们搜索一个更大的范围。
search_start = max(1, mf_delay - sps * 5); % 从理论延迟前 5个符号周期开始
search_end = min(length(S_mf) - (Total_Symbols-1)*sps - 1, mf_delay + P*sps + sps * 5); % 在理论数据结束后 5个符号周期结束前

fprintf('\n--- 阶段 3: 穷举搜索，范围 [%d, %d] ---\n', search_start, search_end);

best_ber = 1;
best_start_index = -1;

% 遍历所有可能的起始采样点
for start_index = search_start : search_end
    
    % 符号抽取索引: 抽取 P+D 个符号
    data_ind = start_index : sps : start_index + (Total_Symbols-1)*sps;
    
    % 检查是否超出信号长度
    if data_ind(end) > length(S_mf)
        break; 
    end
    
    % 抽取符号
    rx_vec = S_mf(data_ind); 
    
    % --- 相位估计和补偿 ---
    preamble_received = rx_vec(1:P);
    
    % 计算平均相位差 (注意: 这一步不处理 90/180/270 度模糊)
    phase_errors = angle(preamble_received(:) .* conj(preamble_ideal(:)));
    avg_phase_error = mean(phase_errors);
    
    % 相位补偿
    rx_vec_compensated = rx_vec * exp(-1j * avg_phase_error);
    
    % --- 判决和比特恢复 ---
    data_symbols = rx_vec_compensated(P+1:end); % 跳过前导码
    
    % 最小距离检测
    metric = abs(repmat(data_symbols.', 1, 4) - repmat(const, length(data_symbols), 1)).^2;
    [~, symbol_indices] = min(metric, [], 2);
    symbol_indices = symbol_indices' - 1; % 转换为 0, 1, 2, 3
    
    % 转换为比特 (a_hat)
    a_hat_data = reshape(de2bi(symbol_indices, 2, 'left-msb')', 1, []);

    % --- BER 计算 ---
    len_recovered = length(a_hat_data);
    
    if len_recovered == num_bits
        bit_errors = sum(a_hat_data ~= X_orig);
        ber = bit_errors / num_bits;
        
        if ber < best_ber
            best_ber = ber;
            best_start_index = start_index;
            
            if best_ber == 0
                fprintf('**完美匹配!** 最佳起始采样点 Index = %d, BER = 0\n', best_start_index);
                break; % 找到完美解，立即退出
            end
        end
    end
end

%% 4. 报告结果
fprintf('\n--- 穷举搜索最终结果 ---\n');
if best_start_index > 0
    fprintf('最佳起始采样点 (最低 BER): **%d**\n', best_start_index);
    fprintf('最低误码率 (BER): **%.8f**\n', best_ber);
    
    if best_ber == 0
        fprintf('结论：恭喜您，找到了理想的符号抽取起始点！\n');
        fprintf('请将 decode_core.m 中的符号抽取逻辑，替换为使用此数值：\n');
        fprintf('start_index = %d;\n', best_start_index);
    else
        fprintf('警告：搜索未能找到零误码率。请检查载波同步和匹配滤波器系数是否正确。\n');
    end
else
    fprintf('搜索失败：在设定范围内未找到有效起始点。\n');
end