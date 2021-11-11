classdef HSV
    methods(Static)
        function [L, A, dL] = Landmarks2Kinematics(lm)
            if size(lm,2) == 4
                vect = lm(:,[1 3]) - lm(:,[2 4]);
            elseif size(lm,2) == 10
                vect = lm(:,[5 15]) - lm(:,[10 20]);
            else
                error('The number of coordinates must be either 4 or 10 but was %i', size(lm,2));
            end
            L = sqrt(vect(:,1).^2 + vect(:,2).^2) * SL.Param.mmPerPx;
            A = atan2d(-vect(:,2), vect(:,1)) - 90;
            dL = SL.HSV.ComputeVelocity(L);
        end
        
        function dL = ComputeVelocity(L)
            dL = NaN(size(L));
            bb = MMath.Logical2Bounds(~isnan(L));
            for i = 1 : size(bb,1)
                ind = bb(i,1) : bb(i,2);
                x = L(ind);
                x = gradient(x, 1./SL.Param.frPerSec);
                dL(ind) = x;
            end
        end
        
        function A = RmAngOutliers(A)
            % Remove outliers within each lick using nearest value
            bb = MMath.Logical2Bounds(~isnan(A));
            for i = 1 : size(bb,1)
                ind = bb(i,1) : bb(i,2);
                a = A(ind);
                a = filloutliers(a, 'nearest', 'quartiles');
                A(ind) = a;
            end
        end
        
        function hh = ViewerUserFunc(~, fIdx, lm)
            % User function for MImgBaseClass.Viewer method
            lm = lm{fIdx};
            hh = plot(lm(:,1), lm(:,2), 'gx');
        end
        
        function hh = ViewerUserFunc2(sIdx, fIdx, C, Y, S)
            % User function for MImgBaseClass.Viewer method
            
            hh = [];
            hId = 0;
            
            % Classification
            if nargin > 2 && ~isempty(C)
                % Find data for the current frame
                if iscell(C)
                    C = C{sIdx};
                end
                C = C(fIdx,:);
                if C(1) > 0.5
                    hId = hId + 1;
                    hh(hId) = text(224/2, 224*0.9, sprintf('Tongue Out'), ...
                        'Color', 'r', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
                else
                    return;
                end
            end
            
            % Regression
            if nargin > 3 && ~isempty(Y)
                hId = hId + 1;
                hh(hId) = plotLandmarks(Y, 'rx');
            end
            
            % Segmentation
            if nargin > 4 && ~isempty(S)
                if iscell(S)
                    S = S{sIdx};
                end
                img = zeros(size(S,1), size(S,2), 3);
                img(:,:,1) = S(:,:,fIdx) == 'tongue_bottom_area';
                
                hId = hId + 1;
                hh(hId) = imagesc(img, 'AlphaData', 0.1);
            end
            
            function h = plotLandmarks(lm, plotStr)
                if iscell(lm)
                    lm = lm{sIdx};
                end
                lm = lm(fIdx,:);
                lm = reshape(lm, [numel(lm)/2, 2]);
%                 h = plot(lm(:,1), lm(:,2), plotStr);
                h = quiver(lm(2,1), lm(2,2), lm(1,1)-lm(2,1), lm(1,2)-lm(2,2), ...
                    'Color', 'r', 'LineWidth', 1.5, 'MaxHeadSize', .6, 'AutoScale', 'off');
            end
        end
        
        function hh = ViewerUserFunc3(~, fIdx, gtStack, predStack)
            % User function for MImgBaseClass.Viewer method
            
            img = zeros(size(gtStack,1), size(gtStack,2), 3);
            img(:,:,2) = gtStack(:,:,fIdx);
            img(:,:,1) = predStack(:,:,fIdx);
            
            hh(1) = imagesc(img, 'AlphaData', 0.5);
        end
        
        function tkData = TrackTrial(vidPath)
            
            % Read all video frames
            vid = MNN.ReadVideo(vidPath);
            
            % Find ROI by image registration with a template
            roiTemplate = imread('roi_template.tif'); % figure; imshow(frTemp);
            [vidTf, tform] = MNN.RoiTransform(vid(:,1:500,:,:), roiTemplate , 'X');
            
            % Resize images
            img = imresize(vidTf, [224 224]);
            
            % Check result
            figure; clf
            imshow(vidTf(:,:,:,end));
            size(img)
            
            % Load networks
            netClassName = 'finished_net_is_tongue_out_20180831-01.mat';
            netClass = load(netClassName);
            netRegName = 'finished_net_tongue_bottom_lm_20180901-01-stage4.mat';
            netReg = load(netRegName);
            netSegName = 'finished_net_tongue_bottom_area_20180829-01.mat';
            netSeg = load(netSegName);
            
            % Run tongue state classification
            tic;
            [C, C_score] = classify(netClass.net, img);
            toc;
            reset(parallel.gpu.GPUDevice.current);
            
            % Run tongue landmark regression
            tic;
            Y = predict(netReg.net, img);
            toc;
            reset(parallel.gpu.GPUDevice.current);
            
            % Run sementic segmentation
            tic;
            S = semanticseg(img, netSeg.net, 'MiniBatchSize', 16);
            toc;
            reset(parallel.gpu.GPUDevice.current);
            
            % Output
            tkData.vidPath = vidPath;
            tkData.img = img;
            tkData.netClassName = netClassName;
            tkData.netRegName = netRegName;
            tkData.netSegName = netSegName;
            tkData.C = C;
            tkData.C_score = C_score;
            tkData.Y = Y;
            tkData.S = S;
        end
        
        function hh = FrameLabels(sIdx, fIdx, C, Y, S)
            % User function for MImgBaseClass.Viewer method
            
            hh = [];
            hId = 0;
            f = gcf;
            f.Name = ['stack ' num2str(sIdx) ' frame ' num2str(fIdx)];
            
            % Classification
            if nargin > 2 && ~isempty(C)
                % Find data for the current frame
                if iscell(C)
                    C = C{sIdx};
                end
                C = C(fIdx,:);
                if C(1) > 0.5
                    title(sprintf('{\\color{red}Tongue Out}'));
                else
                    title('');
                end
            end
            
            % Regression
            if nargin > 3 && ~isempty(Y)
                hId = hId + 1;
                hh(hId) = plotLandmarks(Y, 'rx');
            end
            
            function h = plotLandmarks(lm, plotStr)
                if iscell(lm)
                    lm = lm{sIdx};
                end
                lm = lm(fIdx,:);
                lm = reshape(lm, [numel(lm)/2, 2]);
                % h = plot(lm(:,1), lm(:,2), plotStr);
                h = quiver(lm(2,1), lm(2,2), lm(1,1)-lm(2,1), lm(1,2)-lm(2,2), ...
                    'Color', 'r', 'LineWidth', 1.5, 'MaxHeadSize', 0.2, 'AutoScale', 'off');
            end
            
            % Segmentation
            if nargin > 4 && ~isempty(S)
                if iscell(S)
                    S = S{sIdx};
                end
                img = NaN(size(S,1), size(S,2), 3);
                img(:,:,1) = S(:,:,fIdx) == 'tongue_bottom_area';
                
                hId = hId + 1;
                hh(hId) = imagesc(img, 'AlphaData', 0.1);
            end
        end
        
        function rec = MakeVideoMat(vid, C, Y, S)
            % Produce a RGBT video matrix for HSV labeled with classification, regressions and 
            % segmentation results
            
            clf;
            hImg = imagesc(); hold on
            axis ij equal tight
            colormap gray
            hh = [];
            
            f = gcf;
            f.Color = 'w';
            f.Units = 'pixel';
            f.Position(3:4) = [224 224];
            
            ax = gca;
            axis off
            ax.Units = 'pixel';
            ax.Position = [1 1 224 224];
            
            numFr = size(vid, 4);
            rec(numFr) = struct('cdata', [], 'colormap', []);
            
            for k = 1 : numFr
                delete(hh);
                hh = [];
                hId = 0;
                fr = vid(:,:,:,k);
                
                p = C(k,:);
                if p > 0.5
                    % Classification
                    hId = hId + 1;
                    hh(hId) = text(224/2, 224*0.9, sprintf('Tongue Out'), ...
                        'Color', 'r', 'FontWeight', 'bold', 'HorizontalAlignment', 'center');
                    
                    % Regression
                    lm = Y(k,:);
                    lm = reshape(lm, [numel(lm)/2, 2]);
                    hId = hId + 1;
                    hh(hId) = quiver(lm(2,1), lm(2,2), lm(1,1)-lm(2,1), lm(1,2)-lm(2,2), ...
                        'Color', 'r', 'LineWidth', 1.5, 'MaxHeadSize', .6, 'AutoScale', 'off');
                    
                    % Segmentation
                    segMask = S(:,:,k) == 'tongue_bottom_area';
                    fr(:,:,1) = fr(:,:,1) + uint8(segMask * 255 * 0.1);
                end
                
                hImg.CData = fr;
                
                rec(k) = getframe(ax);
            end
            
            rec = cat(4, rec.cdata);
        end
        
    end
end

