clc
clear
close all

%% ============================================================
%  FRAP Batch Analysis
%
%  Input TXT format:
%       Column 1 = Time (sec)
%       Column 2 = Fluorescence intensity
%
%  FRAP model:
%       F(t) = a * (1 - exp(-b*t))
%
%  Parameters:
%       a  = Mobile fraction (0-1)
%       b  = Recovery rate constant (1/sec)
%
%       HalfTime = ln(2)/b        (sec)
%       Mf       = a*100          (%)
%       IMf      = (1-a)*100      (%)
%
%       D = Diffusion coefficient (um^2/min)
%
%  Normalization:
%
%               F(t) - F0
%       Fnorm = -------------
%               Fpre - F0
%
%       Fpre = Mean pre-bleach fluorescence
%       F0   = Minimum fluorescence after bleaching
%
%  Therefore:
%       Post-bleach = 0
%       Pre-bleach  = 1
%
% ============================================================


%% ================= USER INPUT ================================

defaultAnswer = { ...
    '', ...
    '0.26', ...
    'ALL_WT'};

prompt = { ...
    'Pathway of Folder', ...
    'Bleach Radius (um)', ...
    'Export Name'};

AddOpts.Resize = 'on';
AddOpts.WindowStyle = 'normal';

dlgTitle = 'FRAP Analysis';
lineno = 1;

answer = inputdlg(prompt,dlgTitle,lineno,defaultAnswer,AddOpts);

% Stop if Cancel is pressed
if isempty(answer)
    disp('Analysis cancelled.');
    return
end

Pathway = answer{1};
w = str2double(answer{2});
OutName = answer{3};

if isnan(w) || w <= 0
    error('Bleach radius must be a positive number.');
end


%% ================= FIND TXT FILES =============================

fileList = dir(fullfile(Pathway,'*.txt'));
LF = length(fileList);

if LF == 0
    error('No TXT files found in the selected folder.');
end

fprintf('\n========================================\n');
fprintf('FRAP Batch Analysis\n');
fprintf('Number of files = %d\n',LF);
fprintf('Bleach radius = %.4f um\n',w);
fprintf('========================================\n\n');


%% ================= OUTPUT FOLDER ==============================

outputFolder = fullfile(Pathway,OutName);

if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end


%% ================= INITIALIZATION =============================

hWaitbar = waitbar(0,'Processing FRAP data...');

% Results table storage
Results = cell(LF,7);

% Columns:
% File name
% HalfTime
% D
% Mf
% IMf
% R2
% Status


%% ================= MAIN LOOP ==================================

for k = 1:LF

    FileName = fileList(k).name;
    FilePath = fullfile(Pathway,FileName);

    fprintf('\n----------------------------------------\n');
    fprintf('Processing file %d/%d: %s\n', ...
        k,LF,FileName);

    try

        %% ======================================================
        %  LOAD DATA
        % =======================================================

        Data = load(FilePath);

        % Check data format
        if size(Data,2) < 2
            error('TXT file must contain at least two numeric columns.');
        end

        T = Data(:,1);
        I = Data(:,2);

        % Remove NaN/Inf if present
        valid = isfinite(T) & isfinite(I);

        T = T(valid);
        I = I(valid);

        if length(T) < 5
            error('Not enough valid data points.');
        end


        %% ======================================================
        %  FIND BLEACH POINT
        % =======================================================

        % First occurrence of minimum intensity
        [F0,StartPoint] = min(I);

        if StartPoint <= 1
            error('No pre-bleach data available.');
        end

%         fprintf('Bleach point index = %d\n',StartPoint);
%         fprintf('Bleach time = %.4f sec\n',T(StartPoint));
%         fprintf('Post-bleach minimum = %.4f\n',F0);


        %% ======================================================
        %  PRE-BLEACH INTENSITY
        % =======================================================

        % Mean intensity before bleach
        Fpre = mean(I(1:StartPoint-1));

%         fprintf('Mean pre-bleach intensity = %.4f\n',Fpre);

        if Fpre <= F0
            error('Pre-bleach intensity must be greater than post-bleach intensity.');
        end


        %% ======================================================
        %  RECOVERY DATA
        % =======================================================

        T1 = T(StartPoint:end);
        I_recovery = I(StartPoint:end);

        % Reset bleach time to zero
        T1 = T1 - T1(1);


        %% ======================================================
        %  STANDARD FRAP NORMALIZATION
        %
        %              F(t) - F0
        %  Fnorm = -----------------
        %              Fpre - F0
        %
        % =======================================================

        I3 = (I_recovery - F0) ./ (Fpre - F0);

        % Percentage version only for display/export
        I_percent = I3 * 100;


        %% ======================================================
        %  SAVE NORMALIZED CURVE
        % =======================================================

        fig = figure('Visible','off');

        plot(T1,I_percent,'bo-');

        xlabel('Time (sec)', ...
            'FontSize',20, ...
            'FontName','Times New Roman', ...
            'FontWeight','bold');

        ylabel('Normalized Intensity (%)', ...
            'FontSize',20, ...
            'FontName','Times New Roman', ...
            'FontWeight','bold');

        set(gca,'FontSize',15);

        box on

        BaseName = FileName(1:end-4);

        FigNN = fullfile(outputFolder, ...
            ['Normalized_Intensity_' BaseName '.png']);

        saveas(fig,FigNN);

        close(fig);


        %% ======================================================
        %  EXPORT NORMALIZED DATA
        % =======================================================

        NormalizedData = table( ...
            T1, ...
            I_recovery, ...
            I3, ...
            I_percent, ...
            'VariableNames', ...
            {'Time_sec', ...
             'Raw_Intensity', ...
             'Normalized_Intensity', ...
             'Normalized_Percent'});

        NormalizedFile = fullfile(outputFolder, ...
            ['Normalized_' BaseName '.xlsx']);

        writetable(NormalizedData,NormalizedFile);


        %% ======================================================
        %  FRAP CURVE FITTING
        %
        %  Model:
        %
        %       F(t) = a*(1-exp(-b*t))
        %
        % =======================================================

        f = fittype( ...
            'a*(1-exp(-b*x))', ...
            'independent','x', ...
            'coefficients',{'a','b'});


        %% ======================================================
        %  FIT OPTIONS
        % =======================================================

        opts = fitoptions(f);

        % Initial estimate for mobile fraction
        %
        % Use mean of final 10% of recovery data
        nTail = max(3,round(length(I3)*0.10));

        a0 = mean(I3(end-nTail+1:end));

        % Keep initial value within physical range
        a0 = max(0.01,min(a0,0.99));


        % Initial recovery rate
        b0 = 0.05;


        opts.StartPoint = [a0,b0];

        % Physical constraints
        %
        % 0 <= mobile fraction <= 1
        % b must be positive

        opts.Lower = [0,0];
        opts.Upper = [1,10];


        %% ======================================================
        %  PERFORM FITTING
        % =======================================================

        [coefx,statsx] = fit(T1,I3,f,opts);

        ax = coefx.a;
        bx = coefx.b;

        R2 = statsx.rsquare;


        %% ======================================================
        %  MOBILE / IMMOBILE FRACTION
        % =======================================================

        Mf = ax * 100;

        IMf = (1-ax) * 100;


        %% ======================================================
        %  FITTED CURVE
        % =======================================================

        FI2 = ax .* (1-exp(-bx.*T1));


        %% ======================================================
        %  RECOVERY HALF-TIME
        % =======================================================

        HalfTime = log(2)/bx;


        %% ======================================================
        %  DIFFUSION COEFFICIENT
        %
        %  Original equation:
        %
        %       D = (0.88*w^2)/(4*t1/2)
        %
        %  HalfTime is sec.
        %
        %  *60 converts:
        %       um^2/sec --> um^2/min
        %
        % =======================================================

        D = (0.88*w^2)/(4*HalfTime)*60;


        %% ======================================================
        %  DISPLAY RESULTS
        % =======================================================
% 
%         fprintf('\nFitting results:\n');
% 
%         fprintf('a = %.6f\n',ax);
%         fprintf('b = %.6f 1/sec\n',bx);
% 
%         fprintf('Half-time = %.4f sec\n',HalfTime);
% 
%         fprintf('D = %.6f um^2/min\n',D);
% 
%         fprintf('Mobile fraction = %.2f %%\n',Mf);
% 
%         fprintf('Immobile fraction = %.2f %%\n',IMf);
% 
% 
%         fprintf('R2 = %.6f\n',R2);


        %% ======================================================
        %  FITTING FIGURE
        % =======================================================

        fig1 = figure('Visible','off');

        plot(T1,I3,'ko', ...
            'MarkerSize',4);

        hold on

        plot(T1,FI2,'r-', ...
            'LineWidth',2);

        xlabel('Time (sec)', ...
            'FontSize',20, ...
            'FontName','Times New Roman', ...
            'FontWeight','bold');

        ylabel('Normalized Intensity', ...
            'FontSize',20, ...
            'FontName','Times New Roman', ...
            'FontWeight','bold');

        title(BaseName, ...
            'Interpreter','none');

        legend( ...
            'Experimental Data', ...
            'FRAP Fit', ...
            'Location','best');

        set(gca,'FontSize',15);

        box on


        %% Add fitting parameters to graph

        resultText = sprintf( ...
            ['Half-time = %.2f sec\n' ...
             'D = %.4f um^2/min\n' ...
             'Mf = %.2f %%\n' ...
             'R^2 = %.4f'], ...
             HalfTime,D,Mf,R2);

        text(0.60,0.25,resultText, ...
            'Units','normalized', ...
            'FontSize',11);


        FigN = fullfile(outputFolder, ...
            ['Fitting_' BaseName '.png']);

        saveas(fig1,FigN);

        close(fig1);


        %% ======================================================
        %  INDIVIDUAL RESULT FILE
        % =======================================================

        Parameter = { ...
            'HalfTime (sec)'; ...
            'Diffusion Coefficient (um^2/min)'; ...
            'Mobile Fraction (%)'; ...
            'Immobile Fraction (%)'; ...
            'R2'; ...
            'Fpre'; ...
            'F0'; ...
            'a'; ...
            'b (1/sec)'};

        Value = [ ...
            HalfTime; ...
            D; ...
            Mf; ...
            IMf; ...
            R2; ...
            Fpre; ...
            F0; ...
            ax; ...
            bx];

        ResultTable = table(Parameter,Value);

        FName = fullfile(outputFolder, ...
            [BaseName '_FRAP_Result.xlsx']);

        writetable(ResultTable,FName);


        %% ======================================================
        %  STORE SUMMARY RESULTS
        % =======================================================

        Results{k,1} = FileName;
        Results{k,2} = HalfTime;
        Results{k,3} = D;
        Results{k,4} = Mf;
        Results{k,5} = IMf;
        Results{k,6} = R2;
        Results{k,7} = 'OK';


        %% ======================================================
        %  CLEAR FITTING PARAMETERS
        % =======================================================

        clear coefx statsx ax bx Mf IMf R2 FI2 ...
              HalfTime D f opts a0 b0


    catch ME

        %% ======================================================
        %  ERROR HANDLING
        %
        %  One failed file will NOT stop the whole batch.
        % =======================================================

%         fprintf('\n*** ERROR processing %s ***\n',FileName);
%         fprintf('%s\n',ME.message);

        Results{k,1} = FileName;
        Results{k,2} = NaN;
        Results{k,3} = NaN;
        Results{k,4} = NaN;
        Results{k,5} = NaN;
        Results{k,6} = NaN;
        Results{k,7} = ['ERROR: ' ME.message];

    end


    %% ==========================================================
    %  UPDATE WAITBAR
    % ===========================================================

    waitbar(k/LF,hWaitbar, ...
        sprintf('Progress: %d%%',round(k/LF*100)));

end


%% ================= CLOSE WAITBAR ===============================

if ishandle(hWaitbar)
    close(hWaitbar);
end


%% ================= SUMMARY TABLE ===============================

SummaryTable = cell2table(Results, ...
    'VariableNames',{ ...
    'CellName', ...
    'HalfTime_sec', ...
    'Diffusion_um2_min', ...
    'MobileFraction_percent', ...
    'ImmobileFraction_percent', ...
    'R2', ...
    'Status'});


%% ================= EXPORT SUMMARY ==============================

SummaryFile = fullfile(outputFolder, ...
    [OutName '_FRAP_Summary.xlsx']);

writetable(SummaryTable,SummaryFile);


%% ================= FINISHED ====================================

% fprintf('\n========================================\n');
% fprintf('FRAP analysis completed.\n');
% fprintf('Results saved in:\n%s\n',outputFolder);
% fprintf('========================================\n');