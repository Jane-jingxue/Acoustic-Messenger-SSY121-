<<<<<<< HEAD
% debug_test.m - 深度调试版本
clear; close all;

% 核心参数
fs = 16000; Rs = 200; fc = 4000;
sps = fs/Rs;
num_bits = 432;

% 使用固定的测试数据（便于调试）
rng(1); % 固定随机种子
X_orig = randi([0 1], 1, num_bits);

fprintf('=== 深度调试模式 ===\n');
fprintf('测试比特序列前20位: '); fprintf('%d', X_orig(1:20)); fprintf('\n');

%% 发射机
fprintf('\n--- 发射机调试 ---\n');
s_tx = transmitter(X_orig, fc);
fprintf('发射信号长度: %d, 持续时间: %.3f秒\n', length(s_tx), length(s_tx)/fs);

% 分析发射信号
figure(1); 
subplot(2,1,1); plot(real(s_tx(1:min(5000,length(s_tx)))));
title('发射信号 (前5000点)'); xlabel('采样点'); ylabel('幅度');

%% 接收机深度调试
fprintf('\n--- 接收机深度调试 ---\n');
a_hat = decode_core(s_tx, fc); % 使用调试版本

%% 结果分析
if length(a_hat) == length(X_orig)
    bit_errors = sum(X_orig ~= a_hat);
    BER = bit_errors / num_bits;
    fprintf('\n=== 最终结果 ===\n');
    fprintf('错误比特数: %d/%d\n', bit_errors, num_bits);
    fprintf('误码率: %.6f\n', BER);
    
    if BER == 0
        fprintf('? 测试成功！\n');
    else
        fprintf('? 测试失败\n');
        % 显示错误位置
        error_positions = find(X_orig ~= a_hat);
        fprintf('前10个错误位置: '); 
        fprintf('%d ', error_positions(1:min(10,length(error_positions))));
        fprintf('\n');
    end
else
    fprintf('错误：比特长度不匹配 (%d vs %d)\n', length(a_hat), length(X_orig));
=======
% debug_test.m - 深度调试版本
clear; close all;

% 核心参数
fs = 16000; Rs = 200; fc = 4000;
sps = fs/Rs;
num_bits = 432;

% 使用固定的测试数据（便于调试）
rng(1); % 固定随机种子
X_orig = randi([0 1], 1, num_bits);

fprintf('=== 深度调试模式 ===\n');
fprintf('测试比特序列前20位: '); fprintf('%d', X_orig(1:20)); fprintf('\n');

%% 发射机
fprintf('\n--- 发射机调试 ---\n');
s_tx = transmitter(X_orig, fc);
fprintf('发射信号长度: %d, 持续时间: %.3f秒\n', length(s_tx), length(s_tx)/fs);

% 分析发射信号
figure(1); 
subplot(2,1,1); plot(real(s_tx(1:min(5000,length(s_tx)))));
title('发射信号 (前5000点)'); xlabel('采样点'); ylabel('幅度');

%% 接收机深度调试
fprintf('\n--- 接收机深度调试 ---\n');
a_hat = decode_core(s_tx, fc); % 使用调试版本

%% 结果分析
if length(a_hat) == length(X_orig)
    bit_errors = sum(X_orig ~= a_hat);
    BER = bit_errors / num_bits;
    fprintf('\n=== 最终结果 ===\n');
    fprintf('错误比特数: %d/%d\n', bit_errors, num_bits);
    fprintf('误码率: %.6f\n', BER);
    
    if BER == 0
        fprintf('? 测试成功！\n');
    else
        fprintf('? 测试失败\n');
        % 显示错误位置
        error_positions = find(X_orig ~= a_hat);
        fprintf('前10个错误位置: '); 
        fprintf('%d ', error_positions(1:min(10,length(error_positions))));
        fprintf('\n');
    end
else
    fprintf('错误：比特长度不匹配 (%d vs %d)\n', length(a_hat), length(X_orig));
>>>>>>> 230df9110b2bad0e8544304983446d036875369b
end