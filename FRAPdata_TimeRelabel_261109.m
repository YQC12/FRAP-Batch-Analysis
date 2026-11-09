% Specify the folder containing the Excel files
clc
clear
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~%
prompt = {' Pathway of Fold',' DataLength','IntervalTime(sec)'};
AddOpts.Resize ='on';
AddOpts.WindowStyle='normal';
title='Detetion Size';
lineno=1;
defaultAnswer = {'','', '0.1'};  % 預先填入的值
answer=inputdlg(prompt,title,lineno,defaultAnswer);
Pathway=answer{1,1};
DataLength=str2num(answer{2,1});
TimInt=str2num(answer{3,1});
% LF=length(FileName);
% Input index of time = 0; 
folderPath = Pathway; % Replace with your folder path

% Get a list of all Excel files in the folder
fileList = dir(fullfile(folderPath, '*.xlsx')); % Change '*.xlsx' to '*.xls' if needed
EndP=DataLength;
TimePeroid=TimInt;
numSteps = length(fileList); % 假設有 100 步
% 創建進度條
hWaitbar = waitbar(0, 'Processing...'); % 初始化進度條
% Loop through each file, read the data, and export to a .txt file
for k = 1:length(fileList)
    % Get the full file path of the Excel file
    excelFilePath = fullfile(folderPath, fileList(k).name);    
    % Display the file being read
    fprintf('Processing file: %s\n', fileList(k).name);    
    % Read the Excel file into a table
    data = readmatrix(excelFilePath);
    data1=data(1:EndP,:);
    dataArray =   data1(:,3);
 % Calculate the difference (first derivative)
diffData = diff(dataArray);
[~, idx_first_rise] = max(diffData(1:18));
[~, minIndex0] = min(dataArray);
dataArray(idx_first_rise: minIndex0-1)=[];
dataCleaned=dataArray;
[~, minIndex] = min(  dataCleaned );
% Generate time sequence
timeSequence = ((1:length(  dataCleaned )) - minIndex)'*TimePeroid;
dataArray2 = dataCleaned;   
aLL=[timeSequence, dataArray2];      
    % Generate the output .txt file name (same as Excel file, but with .txt extension)
    [~, fileName, ~] = fileparts(fileList(k).name); % Extract the file name without extension
    txtFilePath = fullfile(folderPath, [fileName, '.txt']);
    
    % Write the table to a .txt file
   writematrix(aLL, txtFilePath, 'Delimiter', '\t');
    pause(0.05); % 假設每一步需要處理的時間
    
    % 更新進度條
    waitbar(k / numSteps, hWaitbar, sprintf('Progress: %d%%', round(k / numSteps * 100))); 
    % Display a message indicating successful export

end
close (hWaitbar )

