<<<<<<< HEAD
% test_loopback.m
% 目的：验证发射机和修改后的接收机在理想（无噪）条件下的兼容性。
% 误码率（BER）必须为 0 才能证明匹配成功。
%% 1. 系统参数和数据初始化
clear; close all;

% 核心参数 (必须与发射机代码中的值完全一致!)
fs = 16000;              % 采样频率
Rs = 200;                % 符号速率
fc = 4000;               % 载波频率 (任选一个，例如 4000 Hz)
num_bits = 432;          % 信息比特数

% 其他固定参数
sps = fs/Rs;             % 每符号采样点数 (80)


%% 2. 发射机：生成信号和“真相”

% 生成随机输入比特 (这是要发送的原始数据，即“真相”)
X_orig = randi([0 1], 1, num_bits); 

% 运行发射机代码，生成实数带通信号 s_tx
% 确保您的 transmitter.m 已修改为返回 s_passband
fprintf('--- 阶段 1: 信号生成与环回 ---\n');
try
s_tx = transmitter(X_orig, fc);
fprintf('发射信号 s_tx 长度: %d 采样点\n', length(s_tx));
catch ME
fprintf(2, '错误：运行 transmitter 函数失败。\n');
fprintf(2, '请确保 transmitter.m 函数定义为: function [s_passband] = transmitter(X, fc)\n');
return;
end
% 模拟环回 (理想的“数学导线”连接)
s_rx = s_tx;
fprintf('成功模拟信号环回（理想无噪信道）。\n');




%% 3. 接收机：核心逻辑解码

% **重要说明：**
% 这一步需要您将接收机代码（audioTimerFcn的主体）封装为一个独立函数
% 例如: function a_hat = decode_core(s_rx, fc)

fprintf('\n--- 阶段 2: 运行接收机核心逻辑 ---\n');

% --------------------------------------------------------------------
% 【关键修改】 强制清晰的变量传递，避免 MATLAB 解析器的误判
% --------------------------------------------------------------------
s_rx_temp = s_rx;
fc_temp = fc;

try
    % 运行解码核心 (使用临时变量调用)
    a_hat = decode_core(s_rx_temp, fc_temp);
catch ME
    % 如果失败，则显示详细的错误信息（ME.message）而不是泛泛的错误
    fprintf(2, '错误：运行 decode_core 函数失败。详细信息:\n');
    fprintf(2, '%s\n', ME.message);
    fprintf(2, '请确保您已将修改后的接收机逻辑封装到 decode_core 函数中。\n');
    return;
end

%% 4. 验证结果（误码率 BER 计算）

% 4.1 长度检查与裁剪
len_recovered = length(a_hat);
if len_recovered < num_bits
fprintf(2, '错误：解码恢复的比特数不足 %d。无法计算 BER。\n', num_bits);
return;
elseif len_recovered > num_bits
% 如果恢复的比特数较长 (可能包含尾部瞬态)，则裁剪
a_hat = a_hat(1:num_bits);
fprintf('注意：解码结果已裁剪至 %d 位。\n', num_bits);
end

% 4.2 计算差异
bit_difference = sum(X_orig ~= a_hat);
BER = bit_difference / num_bits;

%% 5. 结果输出
fprintf('\n--- 阶段 3: 误码率 (BER) 验证 ---\n');
fprintf('总发送比特数: %d\n', num_bits);
fprintf('错误解码比特数: %d\n', bit_difference);
fprintf('误码率 (BER): %.8f\n', BER);

if BER == 0
disp('? **测试成功！** 发射机和接收机在理想条件下完美匹配。可以进行实际声学测试了。');
else
disp('? **测试失败！** BER 不为零。请仔细检查以下参数是否完全一致:');
disp('- fs (16000), Rs (200), sps (80)');
disp('- RRC 参数: alpha (0.20), span (8)');
disp('- Preamble 序列 (Barker-13 码)');
disp('- 符号抽取逻辑 (data_ind 的计算)');
=======
% test_loopback.m
% 目的：验证发射机和修改后的接收机在理想（无噪）条件下的兼容性。
% 误码率（BER）必须为 0 才能证明匹配成功。
%% 1. 系统参数和数据初始化
clear; close all;

% 核心参数 (必须与发射机代码中的值完全一致!)
fs = 16000;              % 采样频率
Rs = 200;                % 符号速率
fc = 4000;               % 载波频率 (任选一个，例如 4000 Hz)
num_bits = 432;          % 信息比特数

% 其他固定参数
sps = fs/Rs;             % 每符号采样点数 (80)


%% 2. 发射机：生成信号和“真相”

% 生成随机输入比特 (这是要发送的原始数据，即“真相”)
X_orig = randi([0 1], 1, num_bits); 

% 运行发射机代码，生成实数带通信号 s_tx
% 确保您的 transmitter.m 已修改为返回 s_passband
fprintf('--- 阶段 1: 信号生成与环回 ---\n');
try
s_tx = transmitter(X_orig, fc);
fprintf('发射信号 s_tx 长度: %d 采样点\n', length(s_tx));
catch ME
fprintf(2, '错误：运行 transmitter 函数失败。\n');
fprintf(2, '请确保 transmitter.m 函数定义为: function [s_passband] = transmitter(X, fc)\n');
return;
end
% 模拟环回 (理想的“数学导线”连接)
s_rx = s_tx;
fprintf('成功模拟信号环回（理想无噪信道）。\n');




%% 3. 接收机：核心逻辑解码

% **重要说明：**
% 这一步需要您将接收机代码（audioTimerFcn的主体）封装为一个独立函数
% 例如: function a_hat = decode_core(s_rx, fc)

fprintf('\n--- 阶段 2: 运行接收机核心逻辑 ---\n');

% --------------------------------------------------------------------
% 【关键修改】 强制清晰的变量传递，避免 MATLAB 解析器的误判
% --------------------------------------------------------------------
s_rx_temp = s_rx;
fc_temp = fc;

try
    % 运行解码核心 (使用临时变量调用)
    a_hat = decode_core(s_rx_temp, fc_temp);
catch ME
    % 如果失败，则显示详细的错误信息（ME.message）而不是泛泛的错误
    fprintf(2, '错误：运行 decode_core 函数失败。详细信息:\n');
    fprintf(2, '%s\n', ME.message);
    fprintf(2, '请确保您已将修改后的接收机逻辑封装到 decode_core 函数中。\n');
    return;
end

%% 4. 验证结果（误码率 BER 计算）

% 4.1 长度检查与裁剪
len_recovered = length(a_hat);
if len_recovered < num_bits
fprintf(2, '错误：解码恢复的比特数不足 %d。无法计算 BER。\n', num_bits);
return;
elseif len_recovered > num_bits
% 如果恢复的比特数较长 (可能包含尾部瞬态)，则裁剪
a_hat = a_hat(1:num_bits);
fprintf('注意：解码结果已裁剪至 %d 位。\n', num_bits);
end

% 4.2 计算差异
bit_difference = sum(X_orig ~= a_hat);
BER = bit_difference / num_bits;

%% 5. 结果输出
fprintf('\n--- 阶段 3: 误码率 (BER) 验证 ---\n');
fprintf('总发送比特数: %d\n', num_bits);
fprintf('错误解码比特数: %d\n', bit_difference);
fprintf('误码率 (BER): %.8f\n', BER);

if BER == 0
disp('? **测试成功！** 发射机和接收机在理想条件下完美匹配。可以进行实际声学测试了。');
else
disp('? **测试失败！** BER 不为零。请仔细检查以下参数是否完全一致:');
disp('- fs (16000), Rs (200), sps (80)');
disp('- RRC 参数: alpha (0.20), span (8)');
disp('- Preamble 序列 (Barker-13 码)');
disp('- 符号抽取逻辑 (data_ind 的计算)');
>>>>>>> 230df9110b2bad0e8544304983446d036875369b
end