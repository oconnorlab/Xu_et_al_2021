classdef Data
    
    properties(Constant)
        % Root directories of raw data
        rawRootNetworkOld = '\\OCONNORDATA10\data10\projectData\SeqLick datastore 1'; % this was primary
        rawRootNetwork = '\\OCONNORDATA11\tongue11\SeqLick datastore 1'; % this is primary
        rawRoot = 'F:\SeqLick datastore 1'; % this is local copy
        
        % Root directories of preprocessed data
        % including master file, original se, tracking and spike sorting results
        preprocessedNetworkRoot = '\\OCONNORDATA11\tongue11\preprocessed'; % this is network copy
        preprocessedRoot = 'E:\preprocessed'; % this is primary
        
        % Working directory for preprocessing
        preprocessingDir = 'D:\preprocessing';
        
        % Paths for data analysis and figure making
        analysisRoot = getenv('SL_ANALYSIS_ROOT');
        figDirName = 'Figures Xu et al';
        metadataSheet = 'SeqLick Master.xlsx';
        
        
        % Animals with unconventional behavioral shaping
        unconventionalShaping = {'MX180202', 'MX180203', 'MX180401', 'MX180501'};
        
        % No learning data
        noLearning = {'VC010102', 'VC010103', 'WO010401', 'WO010402'};
        
        % Sessions where electric lick detection malfunctioned
        % only lickOn, but not lickOff, was correctly registered
        excludeFromTouch = [ ...
            "MX180803 2018-11-22" % M1
            "MX180803 2018-11-23" % M1
            "MX180803 2018-11-28" % S1BF
            "MX180804 2018-12-05" % VPM/PO
            "MX180804 2018-12-06" % VPM/PO
%             "MX181002 2018-12-23" % ? ALM
%             "MX181002 2018-12-24" % ? ALM
%             "MX181003 2018-10-17" % ? opto
%             "MX181003 2018-10-18" % ? opto
            "MX181302 2019-02-01" % SC
            "MX181302 2019-02-10" % M1TJ
            "MX181302 2019-02-12" % M1TJ
            ];
    end
    
    methods(Static)
        function tb = AnimalTable(varargin)
            % Make a table where rows are all animals included in analysis
            
            % Find all enriched se in folders that begin with 'Data', excluding subfolders
            tb = SL.Data.FindSessions('all');
            
            % Group rows of the same animals
            tb = SL.Data.Session2AnimalTable(tb);
            
            % Find which animals were included in the inquired analyses
            for i = 1 : numel(varargin)
                analysisName = varargin{i};
                sessionTb = SL.Data.FindSessions(analysisName);
                for k = 1 : height(tb)
                    tb.(analysisName)(k) = sum(strcmp(sessionTb.animalId, tb.animalId{k}));
                end
            end
        end
        
        function tb = FindSessions(analysisName)
            % Find source sessions for the specified analysis
            
            r = SL.Data.analysisRoot;
            
            % Find source sessions
            switch analysisName
                case 'all'
                    % All enriched se in folders that begin with 'Data', excluding subfolders
                    tb = SL.Data.Dir2Table(fullfile(r, 'Data *', '* se enriched.mat'));
                    
                case 'fig1_seq_stats'
                    % All data excluding behavioral controls, ZZ, opto efficiency
                    tb = [ ...
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys ALM', '* se enriched.mat')); ...
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys M1*', '* se enriched.mat')); ... % including M1TJ, M1B
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys S1*', '* se enriched.mat')); ... % including S1TJ, S1BF, S1L
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys others', '* se enriched.mat')); ...
                        SL.Data.Dir2Table(fullfile(r, 'Data opto VGAT-CRE Ai32 2s 5V', '* se enriched.mat')); ...
                        SL.Data.Dir2Table(fullfile(r, 'Data opto VGAT-CRE Ai32 2s 2.5V', '* se enriched.mat')); ...
                        ];
                    
                case 'fig1_earplug'
                    tb = SL.Data.Dir2Table(fullfile(r, 'Data behav earplug', '* se enriched.mat'));
                    
                case 'fig1_air'
                    tb = SL.Data.Dir2Table(fullfile(r, 'Data behav air', '* se enriched.mat'));
                    
                case 'fig1_numbing'
                    tb = SL.Data.Dir2Table(fullfile(r, 'Data behav numbing', '* se enriched.mat'));
                    
                case 'fig1_learning'
                    % All excluding animals for opto efficiency, unconventional shaping, no learning data
                    tb = [ ...
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys ALM', '* se enriched.mat')); ...
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys M1*', '* se enriched.mat')); ... % including M1TJ, M1B
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys S1*', '* se enriched.mat')); ... % including S1TJ, S1BF, S1L
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys others', '* se enriched.mat')); ...
                        SL.Data.Dir2Table(fullfile(r, 'Data opto VGAT-CRE Ai32 2s 5V', '* se enriched.mat')); ...
                        SL.Data.Dir2Table(fullfile(r, 'Data opto VGAT-CRE Ai32 2s 2.5V', '* se enriched.mat')); ...
%                         SL.Data.Dir2Table(fullfile(r, 'Data behav earplug', '* se enriched.mat')); ...
%                         SL.Data.Dir2Table(fullfile(r, 'Data behav air', '* se enriched.mat')); ...
%                         SL.Data.Dir2Table(fullfile(r, 'Data behav numbing', '* se enriched.mat')); ...
                        ];
                    ind2rm = ismember(tb.animalId, [SL.Data.unconventionalShaping SL.Data.noLearning]);
                    tb(ind2rm,:) = [];
                    
                case 'fig3_efficiency'
                    tb = SL.Data.Dir2Table(fullfile(r, 'Data Opto VGAT-CRE Ai32 efficiency', '* se enriched.mat'));
                    
                case 'fig3_extract_data_5V'
                    % Note: excluded sessions where inhibitions were not 2mm away from other areas
                    tb = SL.Data.Dir2Table(fullfile(r, 'Data Opto VGAT-CRE Ai32 2s 5V', '* se enriched.mat'));
                    
                case 'fig3_extract_data_2.5V'
                    tb = SL.Data.Dir2Table(fullfile(r, 'Data Opto VGAT-CRE Ai32 2s 2.5V', '* se enriched.mat'));
                    
                case 'fig4_unit_quality'
                    tb = [ ...
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys ALM', '* se enriched.mat')); ...
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys M1*', '* se enriched.mat')); ... % including M1TJ, M1B
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys S1*', '* se enriched.mat')); ... % including S1TJ, S1BF, S1L
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys ZZ', '* se enriched.mat')); ...
                        ];
                    
                case 'fig4_recording_sites'
                    tb = SL.Data.Dir2Table(fullfile(r, 'Data ephys *', '* se enriched.mat'));
                    
                case {'fig4_nnmf', 'fig5_seq_coding'}
                    tb = [ ...
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys ALM', '* se enriched.mat')); ...
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys M1*', '* se enriched.mat')); ... % including M1TJ, M1B
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys S1*', '* se enriched.mat')); ... % including S1TJ, S1BF, S1L
                        ];
                    
                case {'fig5_t_lag', 'fig7_cons_coding'}
                    tb = [ ...
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys ALM', '* se enriched.mat')); ...
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys M1TJ', '* se enriched.mat')); ...
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys S1TJ', '* se enriched.mat')); ...
                        ];
                    
                case 'fig6_iti_coding'
                    tb = [ ...
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys ALM', '* se enriched.mat')); ...
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys M1TJ', '* se enriched.mat')); ...
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys S1TJ', '* se enriched.mat')); ...
                        SL.Data.Dir2Table(fullfile(r, 'Data ephys S1BF', '* se enriched.mat')); ...
                        ];
                    
                case 'fig6_behav_stats'
                    tb = SL.Data.Dir2Table(fullfile(r, 'Data ephys ALM', '* se enriched.mat'));
                    
                case 'figZ_seq_coding'
                    tb = SL.Data.Dir2Table(fullfile(r, 'Data ephys ZZ', '* se enriched.mat'));
                    
                otherwise
                    warning('''%s'' is not a valid analysisName', analysisName);
                    tb = table();
            end
        end
        
        function tb = Dir2Table(searchPattern)
            % A wrapper of MBrowse.Dir2Table that also adds session info
            tb = MBrowse.Dir2Table(searchPattern);
            tb.path = fullfile(tb.folder, tb.name);
            [tb.sessionId, tb.animalId] = cellfun(@SL.SE.GetID, tb.name, 'Uni', false);
            tb = tb(:,{'sessionId', 'animalId', 'folder', 'name', 'path'});
        end
        
        function animalTb = Session2AnimalTable(sessionTb)
            % Group row into an animal table
            animalTb = table();
            animalTb.animalId = unique(sessionTb.animalId);
            animalTb = SL.SE.CombineConditions(animalTb, sessionTb);
        end
        
        function xlsTb = SwapSites(xlsTb)
            % Swap opto and recording sites for MX190101 2019-04-16,17,18 to get fig3_efficiency.m running correctly
            % This is just a hack. The original metadata is correct.
            for i = 1 : height(xlsTb)
                sessionId = SL.SE.GetID(xlsTb.animal_id{i}, xlsTb.date(i));
                if ismember(sessionId, {'MX190101 2019-04-16', 'MX190101 2019-04-17', 'MX190101 2019-04-18'})
                    target_area = xlsTb.target_area{i};
                    opto_area = xlsTb.opto_area{i};
                    xlsTb.target_area{i} = opto_area;
                    xlsTb.opto_area{i} = target_area;
                end
            end
        end
        
        function SaveTableAsExcel(fileName, tb, namePairs)
            % Save data source table as Excel spreadsheet
            
            % Remove nested columns
            for i = width(tb) : -1 : 1
                col = tb.(i);
                isNested(i) = iscell(col) && iscell(col{1});
            end
            tb(:,isNested) = [];
            
            % Remove zeros
            for i = 1 : width(tb)
                col = tb.(i);
                if isnumeric(col)
                    col = num2cell(col);
                end
                for j = 1 : numel(col)
                    if col{j} == 0
                        col{j} = [];
                    end
                end
                tb.(i) = col;
            end
            
            % Write table
            filePath = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, fileName);
            writetable(tb, filePath, 'Sheet', 1);
            writecell(namePairs, filePath, 'Sheet', 2);
        end
    end
end


