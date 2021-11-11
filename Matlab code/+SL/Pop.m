classdef Pop
    methods(Static)
        % Linear regression and PCA
        function mdls = FitLinearModels(seTb, ops)
            % Fit data in seTb to linear models
            
            ud = seTb.se(1).userData;
            ud = rmfield(ud, setdiff(fieldnames(ud), {'sessionInfo', 'spikeInfo', 'xlsInfo'}));
            sessionId = SL.SE.GetID(ud.sessionInfo);
            disp(sessionId);
            
            % Make stim and resp matrices
            seTb = SL.SE.SetStimRespArrays(seTb, ops);
            
            % Only keep conditions of interest
            seTb = SL.SE.CombineConditions(ops.conditionTb, seTb);
            
            % Prepare model inputs
            S = cell2mat(seTb.stim);
            R = cell2mat(seTb.resp);
            mu = mean(R);
            k = max(R) + SL.Param.normAddMax;
            R = (R - mu) ./ k;
            sInput.S = S;
            sInput.R = R;
            sInput.sNames = SL.Param.GetAllResampleVars(ops);
            sInput.mu = mu;
            sInput.k = k;
            
            % Compute models
            sLR = SL.Pop.LR(sInput, ops.regVars);
            sPCA = SL.Pop.PCA(sInput);
            
            % Collect and save results
            mdls.sessionId = sessionId;
            mdls.userData = ud;
            mdls.ops = ops;
            mdls.input = sInput;
            mdls.reg = sLR;
            mdls.pca = sPCA;
        end
        
        function sLR = LR(sInput, var4reg)
            % Compute linear regression with centered and scaled input
            % Inputs
            %   sInput.S            Behavioral variables. time-by-var matrix.
            %   sInput.R            Firing rates. time-by-unit matrix.
            %   sInput.sNames       Names of the variables in sInput.S ([ops.hsvVars ops.adcVars ops.valVars])
            %   var4reg             Names of the variables to be used for regression (ops.regVars)
            % Outputs
            %   sLR.subNames        Names of the decoding axes, which is just var2reg.
            %   sLR.sInd            Indices of selected variables in sInput.sNames.
            %   sLR.B               Column vectors of the decoding axes. unit-by-var matrix.
            %   sLR.C               Intercepts. 1-by-var vector.
            %   sLR.lambda          Strength of optimal regularization. 1-by-var vector.
            %   sLR.MSE             MSE with optimal regularization. 1-by-var vector.
            %   sLR.r2cv, sLR.r2    Crossvalidated or overall R-squared. 1-by-var vector.
            %   sLR.varExplained    Variance explained by each decoding axis. 1-by-var vector.
            %   sLR.cosine          Pairwise cosine among the decoding axes. var-by-var matrix.
            
            S = sInput.S;
            R = sInput.R;
            sLR.subNames = var4reg;
            sLR.sInd = SL.Param.FindVarIndices(var4reg, sInput.sNames);
            for i = 1 : numel(sLR.sInd)
                disp(['LR: ' var4reg{i}]);
                s = S(:,sLR.sInd(i));
                [B, fitInfo] = lasso(R, s, 'Alpha', 0.1, 'CV', 10);
                idx = fitInfo.Index1SE;
                sLR.B(:,i) = B(:,idx);
                sLR.C(i) = fitInfo.Intercept(idx);
                sLR.lambda(i) = fitInfo.Lambda(idx);
                sLR.MSE(i) = fitInfo.MSE(idx);
                sLR.r2cv(i) = 1 - sLR.MSE(i) / nanmean((s-nanmean(s)).^2);
            end
            sLR.r2 = MMath.RSquared(R, S(:,sLR.sInd), sLR.B, sLR.C);
            sLR.varExplained = MMath.VarExplained(R, sLR.B);
            sLR.cosine = MMath.VecCosine(sLR.B);
        end
        
        function sPCA = PCA(sInput)
            % Compute PCA with centered and scaled input
            % Inputs
            %   sInput.R            Firing rates. time-by-unit matrix.
            % Outputs
            %   sLR.subNames        Subspace names, e.g. PC1, PC2, PC3, ...
            %   sLR.B               Column vectors of the decoding axes. unit-by-var matrix.
            %   sLR.varExplained    Variance explained by each PC. 1-by-PC vector.
            disp("PCA");
            R = sInput.R;
            sPCA.subNames = cellstr("PC" + (1:size(R,2)));
            [sPCA.B, ~, ~, ~, sPCA.varExplained] = pca(R);
            sPCA.varExplained = sPCA.varExplained';
        end
        
        function s = UnpackLinearModels(mdlsArray, areaList)
            % Pool model data from sessions into tables and compute mean stats for regression
            %   
            % Columns of input/reg/pcaTb
            %   Shared columns are 'sessionId', 'area', 'tLag'
            %   Unique columns correspond to the fields of mdls.input/reg/pca respectively
            % In regAvgTb, each group (row) pools sessions with the same spiking time lag and recording area
            %   regAvgTb.tLag/area                          Spiking time lag and area name
            %   regAvgTb.groupInd                           Session indices that a group includes
            %   regAvgTb.r2mean/r2sd/r2ciLow/r2ciHigh       Mean stats
            
            if ~exist('areaList', 'var')
                areaList = {'S1TJ', 'M1TJ', 'ALM', 'S1BF'};
            end
            
            % Load model files
            if iscellstr(mdlsArray)
                mdlsPaths = mdlsArray;
                for i = 1 : numel(mdlsPaths)
                    load(mdlsPaths{i});
                    mdlsArray{i} = mdls;
                end
            end
            mdlsArray = cat(1, mdlsArray{:});
            
            % Rename variables
            for i = 1 : numel(mdlsArray)
                mdlsArray(i).input.sNames = SL.PopFig.RenameVariables(mdlsArray(i).input.sNames);
                mdlsArray(i).reg.subNames = SL.PopFig.RenameVariables(mdlsArray(i).reg.subNames);
            end
            
            % Make a table of model data
            mdlsTb = struct2table(mdlsArray);
            mdlsTb.animalId = arrayfun(@(x) x.sessionInfo.animalId, mdlsTb.userData, 'Uni', false);
            mdlsTb.area = arrayfun(@(x) x.xlsInfo.area, mdlsTb.userData, 'Uni', false);
            mdlsTb.area = categorical(mdlsTb.area, areaList, 'Ordinal', true);
            mdlsTb.tLag = arrayfun(@(x) x.spkLagInSec, mdlsTb.ops);
            mdlsTb = sortrows(mdlsTb, 'tLag');
            
            % Split the table of models to tables of input, regression and pca, respectively
            sharedCols = {'animalId', 'sessionId', 'area', 'tLag'};
            s.inputTb = [mdlsTb(:,sharedCols) struct2table(mdlsTb.input)];
            s.regTb = [mdlsTb(:,sharedCols) struct2table(mdlsTb.reg)];
            s.pcaTb = [mdlsTb(:,sharedCols) struct2table(mdlsTb.pca)];
            
            % Group sessions by time lag and area
            [G, regAvgTb] = findgroups(mdlsTb(:,{'tLag', 'area'}));
            regAvgTb.groupInd = arrayfun(@(x) G==x, (1:height(regAvgTb))', 'Uni', false);
            
            % Add color code for each area
            regAvgTb.color = SL.Param.GetAreaColors(regAvgTb.area);
            
            % Compute regression mean stats for each group
            [regAvgTb.r2mean, regAvgTb.r2sd] = splitapply(@MMath.MeanStats, s.regTb.r2cv, G);
            r2ci = splitapply(@(x) {bootci(1e3, {@mean,x}, 'Alpha', 0.05)}, s.regTb.r2cv, G);
            regAvgTb.r2ciLow = cell2mat(cellfun(@(x) x(1,:), r2ci, 'Uni', false));
            regAvgTb.r2ciHigh = cell2mat(cellfun(@(x) x(2,:), r2ci, 'Uni', false));
            s.regAvgTb = regAvgTb;
        end
        
        function seTb = SetMeanDeviationArrays(seTb)
            % Compute deviation of state trajectories wrt perfect sequence
            %   Input arrays should be in time-by-variable-by-trial
            %   Output matrices are in time-by-4(m,sd,ci1,ci2)
            
            % Use perfect sequence as the reference state trajectory
            k = height(seTb);
            ref = mean(seTb.pca{k}, 3);
            
            % Compute relative magnitude of state trajectories
            for k = 1 : height(seTb)
                if seTb.numTrial(k) < 8
                    continue
                end
                rel = seTb.pca{k} - ref; % compute relative vectors
                D = sqrt(sum(rel.^2, 2)); % compute vector norms
                [m, sd, ~, ci] = MMath.MeanStats(D, 3); % average across trials
                seTb.avgDevi{k} = cat(3, m, sd, ci);
            end
        end
        
        % Linear decoding
        function [sReg, comTb, mcomTb] = LinearDecoding(seTbArray, mdlsArray, ops)
            
            for i = 1 : numel(seTbArray)
                % Cache variables
                seTb = seTbArray{i};
                mdls = mdlsArray{i};
                
                % Compute stim, resp and projection matrices
                seTb = SL.SE.SetStimRespArrays(seTb, ops);
                seTb = SL.Pop.SetProjArrays(seTb, mdls, 6);
                seTbArray{i} = seTb;
            end
            
            % Combine sessions
            sReg = cellfun(@(x) x.reg, mdlsArray);
            seTb = cat(1, seTbArray{:});
            comTb = SL.SE.CombineConditions(ops.conditionTb, seTb);
            
            % Reduce data size
            comTb.se = [];
            comTb.resp = [];
            
            % Compute mean stats
            mcomTb = SL.SE.SetMeanArrays(comTb);
        end
        
        function seTb = SetProjArrays(seTb, mdls, maxSub)
            % Set projection matrices for each se in seTb
            % The dimensions of an output matrix are the same as the resp matrix except that number
            % of units becomes the number of projected dimensions.
            
            if nargin < 3
                maxSub = Inf;
            end
            
            % Zscore parameters
            mu = mdls.input.mu;
            k = mdls.input.k;
            
            % Regression coeffs
            nB = min(numel(mdls.reg.subNames), maxSub);
            B_reg = mdls.reg.B(:,1:nB);
            C = mdls.reg.C(1:nB);
            
            % PCA coeffs
            nB = min(numel(mdls.pca.subNames), maxSub);
            B_pca = mdls.pca.B(:,1:nB);
            
            for i = 1 : height(seTb)
                % Create variables in the table
                seTb.reg{i} = [];
                seTb.pca{i} = [];
                
                % Iterate through trials, if any
                X = seTb.resp{i};
                for j = size(X,3) : -1 : 1
                    seTb.reg{i}(:,:,j) = (X(:,:,j) - mu)./k * B_reg + C;
                    seTb.pca{i}(:,:,j) = (X(:,:,j) - mu)./k * B_pca;
                end
            end
        end
        
        % Canonical correlation
        function scc = CanonCorr(comTb, varInd)
            
            % Use standard seq
            comTb = comTb(ismember(comTb.seqId, [SL.Param.stdSeqs, SL.Param.zzSeqs]), :);
            
            % Cut continuous time series into sessions
%             colNames = {'time', 'stim', 'reg', 'pca'};
            colNames = {'time', 'reg', 'pca'};
            nTime = length(unique(comTb.time{1}));
            for i = 1 : height(comTb)
                numTrials = comTb.numMatched{i};
                for j = 1 : numel(colNames)
                    cn = colNames{j};
                    val = comTb.(cn){i};
                    val = mat2cell(val, numTrials*nTime);
                    for k = 1 : numel(val)
                        val{k} = reshape(val{k}, nTime, [], size(val{k},2));
                        val{k} = squeeze(mean(val{k}, 2));
                    end
                    comTb.(cn){i} = val;
                end
            end
            
            % Combine trial types for each session
            [G, sessionIds] = findgroups(cat(1, comTb.sessionId{:}));
            t = splitapply(@(x) {cat(1, x{:})}, cat(1, comTb.time{:}), G);
            X = splitapply(@(x) {cat(1, x{:})}, cat(1, comTb.reg{:}), G);
            Y = splitapply(@(x) {cat(1, x{:})}, cat(1, comTb.pca{:}), G);
            
            % Center seq direction
            for i = 1 : numel(X)
                X{i}(:,4) = X{i}(:,4) - 1.5;
            end
            
            % Select subspaces
            X = cellfun(@(x) x(:,varInd), X, 'Uni', false);
            Y = cellfun(@(x) x(:,1:numel(varInd)), Y, 'Uni', false);
            scc.sessionId = sessionIds;
            scc.X = X;
            scc.Y = Y;
            
            % Compute canonical correlations
            rng(61);
            [A, B, r, U, V] = cellfun(@canoncorr, X, Y, 'Uni', false); % U = XA, V = YB, r = p(U,V)
            scc.A = A;
            scc.B = B;
            scc.r = r;
            scc.U = U;
            scc.V = V;
            
            % Similarity
            usim = cellfun(@(x,y) trace(x*y')/sqrt(trace(x*x')*trace(y*y')), U, V);
            scc.usim = usim;
            
            % Tranform PCA traj
            Y2X = cellfun(@(x,y) x/y, V, A, 'Uni', false);
            scc.Y2X = Y2X;
            
            % Compute averages
            X = cat(3, X{:});
%             X(:,2,:) = X(:,2,:) - 1.5; % center seq direction
            Y = cat(3, Y{:});
            Y2X = cat(3, Y2X{:});
            
            scc.t = t{1};
            scc.id = repelem(comTb.seqId, nTime);
            scc.mX = mean(X,3);
            scc.mY = mean(Y,3);
            scc.mr = cellfun(@mean, r);
            scc.mY2X = mean(Y2X,3);
            
            % Output
%             scc.sessionId = sessionIds;
%             scc.usim = usim;
%             scc.t = t{1};
%             scc.id = repelem(comTb.seqId, nTime);
%             scc.X = permute(X, [1 3 2]);
%             scc.Y = permute(Y, [1 3 2]);
%             scc.Xtf = permute(Y2X, [1 3 2]);
%             scc.mr = mr;
%             scc.mX = mX;
%             scc.mY = mY;
%             scc.mXtf = mXtf;
        end
        
        function P = PairwiseTest(M, testType, pairType)
            if ~exist('pairType', 'var')
                pairType = 'independent';
            end
            nGroup = size(M,2);
            P = NaN(nGroup);
            for i = 1 : nGroup
                for j = i+1 : nGroup
                    x = M(:,i);
                    y = M(:,j);
                    if strcmp(pairType, 'paired')
                        y = y - x;
                        x(:) = 0;
                    end
                    switch testType
                        case 'ks'
                            [~, P(i,j)] = kstest2(x, y);
                        case 'perm'
                            P(i,j) = permutationTest(x, y, 10000);
                    end
                end
            end
        end
        
        % Classification
        function [rBoot, rShufBoot] = HierBootClassify(nBoot, claTb)
            % Classify a pair of shift matched sequences with hierarchical bootstrap resampling
            % Inputs
            %   nBoot           The number of resampling
            %   claTb           A table in mClaTb.claTb (output of SL.Pop.UnpackClaConditions), where each 
            %                   row is a different session and all the rows are from the same condition.
            % Outputs
            %   rBoot           Classification acuracy with original data. time-by-nBoot matrix.
            %   rShufBoot       Classification acuracy with shuffled data. time-by-nBoot matrix.
            
            nTime = numel(claTb.time{1});
            rBoot = zeros(nTime, nBoot);
            rShufBoot = rBoot;
            G = findgroups(claTb.animalId);
            
            for n = 1 : nBoot
                % Sampling
                hbInd = MMath.HierBootSample(G);
                
                % Classification in each session
                nSess = numel(hbInd);
                rSess = zeros(nTime, nSess);
                rShufSess = rSess;
                for k = 1 : nSess
                    x1 = claTb.x1{hbInd(k)};
                    x2 = claTb.x2{hbInd(k)};
                    rSess(:,k) = SL.Pop.SVMClassify(x1, x2, 'Resample', true);
                    rShufSess(:,k) = SL.Pop.SVMClassify(x1, x2, 'Resample', true, 'Shuffle', true);
                end
                
                % Average for each animal
                [~, ~, rsG] = unique(G(hbInd)); % group labels must start from 1 and be continuous integers
                rSess = splitapply(@(x) {mean(x,2)}, rSess, rsG');
                rSess = cat(2, rSess{:});
                rBoot(:,n) = mean(rSess, 2);
                
                rShufSess = splitapply(@(x) {mean(x,2)}, rShufSess, rsG');
                rShufSess = cat(2, rShufSess{:});
                rShufBoot(:,n) = mean(rShufSess, 2);
            end
        end
        
        function [r, rCV] = SVMClassify(x1, x2, varargin)
            % Perform crossvalidated SVM (linear kernel) classification across time (3rd dim)
            %   x1 and x2 are trial-by-var-by-time arrays
            %   r is a #time-element vector of classification accuracy
            %   rCV is a time-by-10 where 10 is for 10-fold CV
            
            p = inputParser;
            p.addParameter('Resample', false, @islogical);
            p.addParameter('Shuffle', false, @islogical);
            p.addParameter('Balance', true, @islogical);
            p.addParameter('Standardize', true, @islogical);
            p.parse(varargin{:});
            isResample = p.Results.Resample;
            isShuffle = p.Results.Shuffle;
            isBalance = p.Results.Balance;
            isStd = p.Results.Standardize;
            
            % Get predictors, class labels and weights
            if isResample
                n1 = size(x1, 1);
                n2 = size(x2, 1);
                k = 0.8;
                x1 = x1(randsample(n1, round(n1*k), false),:,:);
                x2 = x2(randsample(n2, round(n2*k), false),:,:);
            end
            
            n1 = size(x1, 1);
            n2 = size(x2, 1);
            N = n1 + n2;
            
            X = cat(1, x1, x2);
            Y = cat(1, zeros(n1,1), ones(n2,1));
            if isShuffle
                Y = randsample(Y, N, false);
            end
            
            W = ones(N,1);
            if isBalance
                W(Y==1) = sum(Y==0) / sum(Y==1);
            end
            
            % Classify across time
            rCV = zeros(size(X,3), 10); % assumes 10-fold
            parfor t = 1 : size(X,3)
                mdl = fitcsvm(X(:,:,t), Y, 'Weight', W, 'CrossVal', 'on', 'Standardize', isStd);
                rCV(t,:) = 1 - mdl.kfoldLoss('mode', 'individual');
            end
            r = mean(rCV, 2);
        end
        
        % Not in use
        function r = MCCV(nSp, X, Y, fitFunc, varargin)
            % Monte-Carlo cross-validation for binary classification
            % 
            % Inputs
            %   nSp         The number of Monte-Carlo sampling
            %   X           m-by-n predictor matrix of m observations and n variables
            %   Y           m-element class label vector
            %   fitFunc     Handle of the fitting function, which accepts a sample of X and Y as inputs
            %               e.g. @(x,y) fitcsvm(x,y)
            % Outputs
            %   r           nSp-element vector of resampled classification accuracy
            
            % Process user inputs
            p = inputParser();
            p.addParameter('fraction', 0.1, @(x) isscalar(x) && x > 0 && x < 1);
            p.parse(varargin{:});
            frac = p.Results.fraction;
            
            % Monte-carlo cross-validation
            nObs = numel(Y);
            nTest = MMath.Bound(round(nObs*frac), [1 nObs]);
            for i = nSp : -1 : 1
                % Partitioning
                indTest = randsample(nObs, nTest);
                isTrain = true(size(Y));
                isTrain(indTest) = false;
                % Model fitting
                mdl = fitFunc(X(isTrain,:), Y(isTrain));
                % Validation
%                 nExpand = 100;
%                 indTest = randsample(indTest, nExpand, true); % bootstrap expansion to reduce quantization
                XTest = X(indTest,:);
                YTest = Y(indTest,:);
                YTestHat = predict(mdl, XTest);
                r(i) = mean(YTest == YTestHat);
            end
        end
        
        function seTb = SetDistMatrices(seTb, ops)
            % Compute pairwise distance of states resulting in time-by-dist matrices
            % The input matrices should be time-by-variable-by-trial
            
            if height(seTb) ~= 2
                error('seTb must have and only have two conditions');
            end
            
            % Unpack parameters from ops
            iShift = ops.iShift;
            tWin = ops.rsWin;
            xInd = [2 1];
            
            for k = 1 : 2
                % Find time and indices in the window
                t = seTb.time{k}(:,:,1);
                iWin = find(t > tWin(1) & t < tWin(2));
                seTb.time{k} = t(iWin);
                
                % Dist within condition and across conditions with the same window
                M1 = permute(seTb.pca{k}(iWin,:,:), [3 2 1]);
                M2 = permute(seTb.pca{xInd(k)}(iWin,:,:), [3 2 1]);
                for i = numel(iWin) : -1 : 1
                    dAuto(i,:) = pdist(M1(:,:,i)); % within condition
                    dXmat = pdist2(M1(:,:,i), M2(:,:,i)); % across conditions
                    dX(i,:) = dXmat(:);
                end
                seTb.auto{k} = dAuto;
                seTb.xSame{k} = dX;
                
                % Dist across conditions with shifted window
                M1 = permute(seTb.pca{1}(iWin,:,:), [3 2 1]);
                M2 = permute(seTb.pca{2}(iWin+iShift(xInd(k)),:,:), [3 2 1]);
                for i = numel(iWin) : -1 : 1
                    dXmat = pdist2(M1(:,:,i), M2(:,:,i));
                    dX(i,:) = dXmat(:);
                end
                seTb.xShifted{k} = dX;
            end
            seTb(:,{'stim','resp','reg','pca'}) = [];
        end
        
        function distTb = MeanDist(distTb)
            % Compute mean stats of pairwise state distances
            
            % Prepare a new row for pooled data
            distTb = distTb([1 2 1], :);
            distTb.seqId(3) = categorical(NaN);
            distTb.se(3) = MSessionExplorer();
            distTb.numTrial(3) = sum(distTb.numTrial([1 2]));
            distTb.numMatched(3) = sum(distTb.numMatched([1 2]));
            
            distNames = {'auto','xSame','xShifted'};
            for i = 1 : numel(distNames)
                % Add pooled data
                dn = distNames{i};
                D = cat(2, distTb.(dn){:});
                distTb.(dn){3} = D;
                
                % Compute each condition
                for j = 1 : height(distTb)
                    d = distTb.(dn){j};
                    [m, ~, ~, ci] = MMath.MeanStats(d, 2, 'Alpha', 0.05);
                    distTb.(dn){j} = [m ci];
                end
            end
        end
        
    end
end

