classdef Error
    methods(Static)
        % Classification
        function cTb = ClassifyBraching(seTb, predName, alpha)
            % Classify standard seq vs backtraking seq in a session
            %   seTb                One row is std seqs, one row is backtracking seqs. The size
            %                       of predictor matrices are time-by-variable-by-trial.
            %   predName            Predictor name. 'pca' or 'resp'
            %   alpha               Significance level
            %   cTb                 A single row table with classification data and result.
            
            if height(seTb) ~= 2
                error('seTb must have and only have two conditions');
            end
            
            s = struct;
            s.animalId = seTb.animalId{1};
            s.sessionId = seTb.sessionId{1};
            s.time = seTb.time{1}(:,:,1);
            s.x1 = permute(seTb.(predName){1}, [3 2 1]); % to trial-by-variable-by-time
            s.x2 = permute(seTb.(predName){2}, [3 2 1]);
            
            % Classify original data
            [s.r, s.rCV] = SL.Pop.SVMClassify(s.x1, s.x2);
            s.rStats = [s.r NaN(numel(s.r), 2)];
            
            nIter = 100;
            for i = nIter : -1 : 1
                % Classify original data with bootstraping
                [s.rBoot(:,i), s.rBootCV(:,:,i)] = SL.Pop.SVMClassify(s.x1, s.x2, 'Resample', true);
                
                % Classify shuffled data
                [s.rShuf(:,i), s.rShufCV(:,:,i)] = SL.Pop.SVMClassify(s.x1, s.x2, 'Shuffle', true);
            end
            s.rBootStats = [mean(s.rBoot,2) prctile(s.rBoot, [alpha/2 1-alpha/2]*100, 2)];
            s.rShufStats = [mean(s.rShuf,2) prctile(s.rShuf, [alpha/2 1-alpha/2]*100, 2)];
            
            cTb = struct2table(s, 'AsArray', true);
        end
        
        function tb = ClaOnsetHist(tb)
            % 
            
            for i = 1 : height(tb)
                % Find indices for baseline (i.e. before backtracking was trigger)
                t = tb.time{i};
                indPre = t <= 0;
                
                % Calculate mean and SD of bootstrap accuracy during baseline
                rBoot = tb.rBoot{i};
                rBootPre = rBoot(indPre,:);
                [m, sd] = MMath.MeanStats(rBootPre(:)); % collapse time
                
                % Find classification onset times for each resampling
                isPass = rBoot > m + sd*3;  % use 3-SD as criterion
                nCons = 3;                  % require 3 consecutive samples passing threshold
                nBoot = size(rBoot, 2);
                tOn = NaN(1, nBoot);
                for j = 1 : nBoot
                    winPass = MMath.Logical2Bounds(isPass(:,j));
                    iSig = find(diff(winPass,1,2)+1 >= nCons, 1);
                    if ~isempty(iSig)
                        tOn(j) = t(winPass(iSig,1)); % take the onset time
                    end
                end
                tb.tOnset{i} = tOn;
            end
        end
        
        function [p, d, sd] = ClaOnsetTest(s1, s2)
            % 
            [~, p] = MMath.BootTest2(s1, s2);
            dd = s2 - s1;
            d = nanmean(dd);
            sd = nanstd(dd);
        end
        
    end
end

