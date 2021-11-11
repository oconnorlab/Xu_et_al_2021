classdef Unit
    
    methods(Static)
        function AddSpikeRateTable(se, ops)
            
            % Vectorize spike times
            seSpk = se.Duplicate({'spikeTime'}, false);
            seSpk.SliceSession(0, 'absolute');
            
            % Clean ISI violated spikes
            spk = seSpk.GetTable('spikeTime');
            spk = SL.Unit.CleanSpikes(spk, 1e-3);
            
            % Add time lag
            for i = 1 : width(spk)
                spk.(i){1} = spk.(i){1} + ops.spkLagInSec(1);
            end
            seSpk.SetTable('spikeTime', spk);
            
            % Binning
            tEdges = 0 : ops.spkBinSize : se.userData.spikeInfo.recording_time;
            r = seSpk.ResampleEventTimes('spikeTime', tEdges, 'Normalization', 'countdensity');
            
            % Smoothing
            for i = 2 : width(r)
                r.(i){1} = MNeuro.Filter1(r.(i){1}, 1/ops.spkBinSize, 'gaussian', ops.spkKerSize);
            end
            seSpk.SetTable('spikeRate', r, 'timeSeries', 0);
            seSpk.RemoveTable('spikeTime');
            
            % Reslice
            tRef = se.GetReferenceTime('spikeTime');
            seSpk.SliceSession(tRef, 'absolute');
            r = seSpk.GetTable('spikeRate');
            se.SetTable('spikeRate', r, 'timeSeries', tRef);
        end
        
        function [spk_tb, vio_table] = CleanSpikes(spk_tb, isi_limit)
            % Remove the second spikes with ISI less than the specified amount
            
            % remove ISI violated spikes
            spk_cell = table2cell(spk_tb);
            vio_cell = cell(size(spk_cell));
            
            for i = 1:numel(spk_cell)
                is_vio = diff(spk_cell{i}) < isi_limit;
                is_vio = [false; is_vio(:)];
                if any(is_vio)
                    vio_cell{i} = spk_cell{i}(is_vio);
                    spk_cell{i} = spk_cell{i}(~is_vio);
                end
            end
            
            spk_tb{:,:} = spk_cell;
            vio_table = cell2table(vio_cell, 'VariableNames', spk_tb.Properties.VariableNames);
        end
        
        function RemoveOffTargetUnits(se, AOI)
            % Remove data and metadata of off-target units
            
            AOI = cellstr(AOI);
            
            % Find indices of removal
            uTb = SL.Unit.UnitInfo(se);
            ind2rm = ~ismember(uTb.areaName, AOI);
            assert(~all(ind2rm), 'No unit is in the area(s) of interest');
            fprintf('Remove %d from %d units (%.1f%%)\n', sum(ind2rm), numel(ind2rm), sum(ind2rm)./numel(ind2rm)*100);
            if ~any(ind2rm)
                return;
            end
            ind2rm = find(ind2rm);
            
            % Spike times
            spkTb = se.GetTable('spikeTime');
            spkTb(:,ind2rm+1) = [];
            se.SetTable('spikeTime', spkTb);
            
            % Pre-task spike times
            se.userData.preTaskData.spikeTime(:,ind2rm+1) = [];
            
            % Metadata
            kInfo = se.userData.spikeInfo;
            kInfo.unit_mean_template(:,:,ind2rm) = [];
            kInfo.unit_mean_waveform(:,ind2rm) = [];
            kInfo.unit_channel_ind(ind2rm) = [];
            se.userData.spikeInfo = kInfo;
        end
        
        function uTb = UnitInfo(se)
            
            % Basic info
            disp(SL.SE.GetID(se));
            sInfo = se.userData.sessionInfo;
            animalId = sInfo.animalId;
            sessionDatetime = datetime(sInfo.sessionDatetime);
            
            % Get sorting info
            kInfo = se.userData.spikeInfo;
            uChanInd = kInfo.unit_channel_ind';
            nUnits = numel(uChanInd);
            uWaveform = num2cell(kInfo.unit_mean_waveform', 2);
            
            % Initialize certain info
            uArea = repmat({''}, [nUnits 1]);
            uDepth = NaN(size(uChanInd));
            
            if isfield(se.userData, 'xlsInfo')
                xInfo = se.userData.xlsInfo;
                
                % Find unit depths along the penetration
                switch xInfo.probe
                    case 'H3'
                        uDepth = xInfo.penet_depth - (uChanInd-1) * 20;
                    case 'H2'
                        uChanInd2 = mod(uChanInd-1, 32);
                        uDepth = xInfo.penet_depth - uChanInd2 * 25;
                    case 'Tetrode32'
                        uDepth = NaN(size(uChanInd));
                    otherwise
                        error('The probe type ''%s'' is not valid', xInfo.probe);
                end
                
                % Assign area label by iterating through all area# fields
                a = 0;
                while true
                    a = a + 1;
                    fn = ['area' num2str(a)];
                    if isempty(xInfo.(fn))
                        if a == 1
                            warning('Histological localization is not available. Label all units by the area targetted.');
                            uArea(:) = {xInfo.area};
                        end
                        break
                    end
                    area = xInfo.(fn);
                    range = eval(xInfo.(['range' num2str(a)])) * 1e3;
                    uHight = xInfo.penet_depth - uDepth;
                    isIn = range(1) <= uHight & uHight < range(2);
                    uArea(isIn) = {area};
                    if all(~cellfun(@isempty, uArea))
                        break
                    end
                end
                
                
                % Use angle to convert penetration depth to cortical depth
                if ~isnan(xInfo.angle)
                    uDepth = round(uDepth * cosd(xInfo.angle));
                end
            else
                warning('xlsInfo is not availble. Placeholder values are used.');
            end
            
            % Combine results
            uTb = table();
            uTb.animalId = repmat({animalId}, [nUnits,1]);
            uTb.sessionDateTime = repmat(sessionDatetime, [nUnits,1]);
            uTb.areaName = uArea;
            uTb.unitNum = (1 : nUnits)';
            uTb.chanInd = uChanInd;
            uTb.depth = uDepth;
            uTb.meanWaveform = uWaveform;
        end
        
        function uTb = UnitQuality(se, masterPath)
            % 
            
            spkTb = se.GetTable('spikeTime');
            rt = se.GetReferenceTime;
            if exist('masterPath', 'var')
                matObj = matfile(masterPath);
                spkData = matObj.spike_data;
            end
            
            uTb = SL.Unit.UnitInfo(se);
            for k = 1 : height(uTb)
                % Vectorize spike times
                t = cell2mat(cellfun(@(x,y) x + y, spkTb{:,k}, num2cell(rt), 'Uni', false));
                t = unique(t); % remove merging artifacts - Kilosort or Phy's bug?
                itvl = diff(t);
                r = 1 ./ itvl;
                
                % ISI histogram and FA rate
                tEdges = 0 : 0.5e-3 : 0.02;
                nISI = histcounts(itvl, tEdges);
                FA = sum(nISI(tEdges < SL.Param.minISI)) / numel(itvl);
                uTb.isiEdges{k} = tEdges;
                uTb.isiCount{k} = nISI;
                uTb.FA(k) = FA * 100;
                
                % Contamination rate
                isActive = r > SL.Param.minActive;
                rMean = sum(isActive) / sum(itvl(isActive));
                c = MNeuro.ClusterContamination(FA, rMean, SL.Param.minISI);
                uTb.meanSpkRate(k) = rMean;
                uTb.contam(k) = c * 100;
                
                if exist('spkData', 'var')
                    % SNR
                    wfAll = spkData.spike_waveforms{k};
                    wfMean = uTb.meanWaveform{k};
                    noises = wfAll - wfMean;
                    uTb.SNR(k) = (max(wfMean) - min(wfMean)) / std(noises(:));
                    
                    % Compute waveform stats
                    uTb.sdWaveform{k} = std(wfAll);
                    uTb.madWaveform{k} = mad(wfAll,1);
                    
                    % Randomly sample raw waveforms
                    rng(61);
                    randInd = randsample(size(wfAll,1), 200);
                    uTb.randWaveform{k} = wfAll(randInd,:);
                end
            end
        end
        
        function uTb = UnitPETH(se, ops)
            %
            if numel(se) > 1
                % Recurse thorugh each SE
                for i = numel(se) : -1 : 1
                    if nargin < 2
                        ops = se(i).userData.ops;
                    end
                    uTb = SL.Unit.UnitPETH(se(i), ops(min(end,i)));
                    peakSpkCount(:,i) = uTb.peakSpkCount;
                    peakSpkRate(:,i) = uTb.peakSpkRate;
                    tt{i} = uTb.tt1;
                    hh{i} = uTb.hh1;
                    ee{i} = uTb.ee1;
                end
                
                % Compute overall stats
                uTb.peakSpkCount = max(peakSpkCount, [], 2);
                uTb.peakSpkRate = max(peakSpkRate, [], 2);
                
                % Add sub PETHs
                for i = 1 : numel(se)
                    uTb.(['tt' num2str(i)]) = tt{i};
                    uTb.(['hh' num2str(i)]) = hh{i};
                    uTb.(['ee' num2str(i)]) = ee{i};
                end
            else
                % Session info
                disp(SL.SE.GetID(se));
                
                % Compute histograms
                tWin = ops.rsWin;
                tEdges = (tWin(1) : ops.rsBinSize : tWin(2))';
                tCenters = mean([tEdges(1:end-1), tEdges(2:end)], 2);
                if ismember('spikeRate', se.tableNames)
                    srTb = se.ResampleTimeSeries('spikeRate', tEdges);
                    [hh, ee, stats] = MNeuro.MeanTimeSeries(srTb{:,2:end});
                else
                    stTb = se.GetTable('spikeTime');
                    [hh, ee, stats] = MNeuro.MeanEventRate(stTb, tEdges);
                end
                
                % Combine results
                uTb = table();
                uTb.unitNum = stats.colNum;
                uTb.peakSpkCount = stats.pkVal * ops.rsBinSize;
                uTb.peakSpkRate = stats.pkVal;
                uTb.tt1 = repmat(tCenters', [height(uTb), 1]);
                uTb.hh1 = hh';
                uTb.ee1 = ee';
            end
        end
        
        function [hh, ind] = SortPETHs(hh, methodStr)
            % Sort PETH (or any time series) by certain criteria
            if nargin < 2
                methodStr = '';
            end
            switch methodStr
                case 'sum'
                    [~, ind] = sort(sum(hh), 'descend');
                case 'csc'
                    [~, ind] = sort(sum(cumsum(hh)), 'descend');
                case 'cosine'
                    r_vect = pdist(hh', 'cosine');
                    r = squareform(r_vect);
                    r_sum = nansum(r);
                    [~, ind] = sort(r_sum, 'ascend');
                case 'dist'
                    r_vect = pdist(hh', 'hamming');
                    r = squareform(r_vect);
                    r_sum = nansum(r);
                    [~, ind] = sort(r_sum, 'descend');
                case 'peak'
                    [~, maxInd] = max(hh);
                    [~, ind] = sort(maxInd, 'ascend');
                case 'com'
                    cs = cumsum(hh);
                    cs = cs > max(cs)./2;
                    [~, ind] = sort(sum(cs), 'descend');
                otherwise
                    ind = 1 : size(hh,2);
            end
            hh = hh(:,ind);
        end
        
        function s = NNMFClustering(X, numComp)
            
            % Perform NNMF
            [W, H] = nnmf(X', numComp);
            
            % Sort components by peak time
            [nUnit, nBin] = size(X);
            hh = mat2cell(W, repelem(nBin/6, 6));
            hh = max(vertcat(hh{1:2:6}), vertcat(hh{2:2:6}));
            [~, I] = SL.Unit.SortPETHs(hh, 'peak');
            W = W(:,I);
            H = H(I,:);
            
            % Find cluster membership by the maximum coefficient
            [maxH, maxInd] = max(H);
            
            s.W = W;
            s.H = H;
            s.maxH = maxH';
            s.clustId = maxInd';
            s.numComp = numComp;
        end
        
        function s = NNMFBoot(X, varargin)
            
            p = inputParser();
            p.addParameter('nComp', 10, @isscalar);
            p.addParameter('nBoot', 1e3, @isscalar);
            p.addParameter('fraction', .9, @isscalar);
            p.parse(varargin{:});
            nComp = p.Results.nComp;
            nBoot = p.Results.nBoot;
            frac = p.Results.fraction;
            
            [nUnit, nBin] = size(X);
            nSample = round(nUnit*frac);
            
            % Compute template
            rng(nComp);
            s = SL.Unit.NNMFClustering(X, nComp);
            W0 = s.W;
            
            % Bootstrap iterations
            rng(61);
            rsInd = cell(nBoot, 1);
            bootW = NaN(nBin, nComp, nBoot);
            parfor n = 1 : nBoot
                disp(n);
                rng(nComp+n, 'twister');
                
                % Random sampling without replacement
                ind = randsample(nUnit, nSample, false);
                ind = MMath.Ind2Logical(ind, nUnit);
                
                % Factorization
                [W, ~] = nnmf(X(ind,:)', nComp);
                
%                 % Sort components by peak time
%                 hh = mat2cell(W, repelem(nBin/6, 6));
%                 hh = max(vertcat(hh{1:2:6}), vertcat(hh{2:2:6}));
%                 [~, I] = SL.Unit.SortPETHs(hh, 'peak');
%                 W = W(:,I);
                
                rsInd{n} = ind;
                bootW(:,:,n) = W;
            end
            
            % 
            bootId = NaN(nUnit, nBoot);
            bootScore = NaN(nUnit, nBoot);
            parfor n = 1 : nBoot
                % Sort components by matching to template
                W = bootW(:,:,n);
                r = corr(W, W0);
                [~, rInd] = sort(r(:), 'descend');
                I = zeros(nComp, 1);
                for m = 1 : numel(rInd)
                    [i, j] = ind2sub([nComp nComp], rInd(m));
                    if ~I(j) && ~ismember(i, I)
                        I(j) = i;
                    end
                    if all(I)
                        break
                    end
                end
%                 [~, I] = max(r);
%                 if unique(I) < nComp
%                     warning('Components cannot be uniquely registered to template');
%                     continue
%                 end
                W = W(:,I);
                
                % Find cluster membership of the held-out units
                ind = rsInd{n};
                Hout = W \ X(~ind,:)';
                [maxHout, I] = max(Hout);
                id = NaN(nUnit,1);
                id(~ind) = I;
                maxH = NaN(nUnit,1);
                maxH(~ind) = maxHout;
                
                bootW(:,:,n) = W;
                bootId(:,n) = id;
                bootScore(:,n) = maxH;
            end
            
            % Find most likely cluster membership
            for i = nUnit : -1 : 1
                % Compute probability distribution of cluster ID for each unit
                idProb(i,:) = histcounts(bootId(i,:), (1:nComp+1)-0.5);
                idProb(i,:) = idProb(i,:) ./ sum(idProb(i,:));
                
                % Find maximum likelihood and the corresponding cluster ID
                [maxProb(i,1), maxId(i,1)] = max(idProb(i,:));
                
                % Compute mean cluster weight of this cluster
                maxIdScore(i,1) = mean(bootScore(i, bootId(i,:) == maxId(i)));
            end
            
            s.nComp = nComp;
            s.W0 = W0;
            s.bootW = bootW;
            s.bootId = bootId;
            s.idProb = idProb;
            s.maxProb = maxProb;
            s.maxId = maxId;
            s.maxIdScore = maxIdScore;
        end
        
        function [unitTb, s] = NNMFExpress(unitTb, nComp)
            % 
            
            % Construct input
            X = unitTb{:,{'hh1', 'hh2', 'hh3', 'hh4', 'hh5', 'hh6'}};
            X = downsample(X', 10, 4)';
            % X = X ./ (max(X, [], 2) + SL.Param.normAddMax);
            X = X ./ max(X, [], 2);
            
            % NNMF clustering
            rng(nComp);
            s = SL.Unit.NNMFClustering(X, nComp);
            
            % Add cluster info to unitTb
            unitTb.clustId = s.clustId;
            unitTb.clustScore = s.maxH;
        end
        
        function [diffTb, unitErr] = DiffPETH(unitTb1, unitTb2)
            % 
            
            hh = {'hh1', 'hh2', 'hh3', 'hh4', 'hh5', 'hh6'};
            diffTb = unitTb1;
            for i = numel(hh) : -1 : 1
                diffTb.(hh{i}) = abs(unitTb1.(hh{i}) - unitTb2.(hh{i})); % compute difference in absolute error
            end
            normErr = diffTb{:,hh} ./ max(unitTb1.peakSpkRate, unitTb2.peakSpkRate);
            unitErr = sqrt(mean(normErr.^2, 2));
        end
        
        function hh = SplitVectorized(W)
            nBin = size(W,1);
            hh = mat2cell(W, repelem(nBin/6, 6));
            hh = cat(3, vertcat(hh{1:2:6}), vertcat(hh{2:2:6}));
        end
        
        function s = TsneClustering(X)
             
            % Run t-SNE
            [coorEmbed, tsneLoss] = tsne(X, ...
                'Algorithm', 'exact', ...
                'Distance', 'cosine', ...
                'NumDimensions', 2, ...
                'Perplexity', 50, ...
                'Standardize', false);
            s.coorEmbed = coorEmbed;
            s.tsneLoss = tsneLoss;
            
            % Fit models with various number of components
            k = 0;
            while k < 20
                try
                    k = k + 1;
                    gmms{k} = fitgmdist(coorEmbed, k, ...
                        'Options', statset('MaxIter',500), ...
                        'CovarianceType', 'diagonal');
                catch e
                    warning('fitgmdist failed with %d components', k);
                    disp(e);
                    break;
                end
            end
             
            % Find the best model and cluster data points
            bicVal = cellfun(@(x) x.BIC, gmms);
            [~, k] = min(bicVal);
            s.gmmBest = gmms{k};
            [s.clustId, ~, s.prob] = cluster(s.gmmBest, coorEmbed);
            s.numComp = s.gmmBest.NumComponents;
        end
        
        function s = ClusterStats(unitTb)
            
            % Compute histograms about the sampling of units
            s.numUnits = height(unitTb);
            var4hist = {'animalId', 'sessionDateTime', 'areaName'};
            for i = 1 : numel(var4hist)
                [N, C] = histcounts(categorical(unitTb.(var4hist{i})));
                s.(var4hist{i}) = C;
                s.([var4hist{i} 'N']) = N;
            end
            
            % Compute histogram about clustering
            [s.clustScoreN, s.clustScore] = histcounts(-unitTb.clustScore, 20);
            
            % Compute mean PETHs
            ishh = startsWith(unitTb.Properties.VariableNames, 'hh');
            for i = sum(ishh) : -1 : 1
                s.tt(:,i) = unitTb.(['tt' num2str(i)])(1,:)';
                hh = unitTb.(['hh' num2str(i)])' ./ unitTb.peakSpkRate';
%                 [s.mm(:,i), s.sd(:,i), s.se(:,i), s.ci(:,i,:)] = MMath.MeanStats(hh, 2);
                [s.mm(:,i), s.sd(:,i), s.se(:,i)] = MMath.MeanStats(hh, 2);
            end
        end
        
        function [N, P] = ClustSizeByDepth(unitTb, areaName)
            % Compute the number of units from each clsuter at different cortical depths
            
            % Select units
            if strcmpi(areaName, 'all')
                isArea = true(height(unitTb), 1);
            else
                isArea = strcmp(areaName, unitTb.areaName);
            end
            unitSubTb = sortrows(unitTb(isArea,:), {'clustId', 'clustScore'});
            
            % Discretize depth
            d = unitSubTb.depth;
            dEdges = [0 400 600 800 1000 1400];
            [~, ~, D] = histcounts(d, dEdges);
            
            % Combine cluster
            I0 = unitSubTb.clustId;
            I = I0;
            I(ismember(I0, [3 4 5 6])) = 3;
            I(ismember(I0, [8 9 10 11])) = 8;
            I(ismember(I0, [12 13])) = 12;
            I(I0==7) = 14;
            
            % Compute histogram
            nClust = numel(unique(I));
            nDepth = numel(dEdges)-1;
            clustNames = categorical(unique(I));
            N = zeros(nClust, nDepth);
            for i = 1 : nDepth
                N(:,i) = histcounts(categorical(I(D==i)), clustNames);
            end
            P = N ./ sum(N);
        end
    end
    
end

