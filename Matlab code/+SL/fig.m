%% Make folders

figNames = {'Fig1', 'Fig2', 'Fig3', 'Fig4', 'Fig5', 'Fig6', 'Fig7', 'FigZ'};
for i = 1 : numel(figNames)
    figPath = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, figNames{i});
    if ~exist(figPath, 'dir')
        mkdir(figPath);
    else
        disp([figNames{i} ' has been created'])
    end
end


%% Figure 1

clear
SL.fig1_examples;

clear
SL.fig1_seq_stats;

clear
SL.fig1_lick_profiles;

clear
SL.fig1_shooting;

clear
SL.fig1_nn_test; % can only run on Many's desktop due to data location

clear
SL.fig1_nn_vs_human;

clear
SL.fig1_perch_calib;

clear
SL.fig1_earplug;

clear
SL.fig1_air;

clear
SL.fig1_numbing;

clear
SL.fig1_learning;


%% Figure 2

clear
SL.fig2_examples;

clear
SL.fig2_reloc_stats;

clear
SL.fig2_lick_profiles;

clear
SL.fig2_seq_stats;

clear
SL.fig2_learning;


%% Figure 3

clear
SL.fig3_efficiency;

% 5V
figDir = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, 'Fig3', '5V');
if ~exist(figDir, 'dir')
    mkdir(figDir);
end

clear
powerName = '5V';
SL.fig3_examples;

clear
powerName = '5V';
SL.fig3_extract_data;

clear
powerName = '5V';
SL.fig3_quant_stats;

clear
powerName = '5V';
SL.fig3_rate_stats;

clear
powerName = '5V';
SL.fig3_brain_overlay;

% 2.5V
figDir = fullfile(SL.Data.analysisRoot, SL.Data.figDirName, 'Fig3', '2.5V');
if ~exist(figDir, 'dir')
    mkdir(figDir);
end

clear
powerName = '2.5V';
SL.fig3_extract_data;

clear
powerName = '2.5V';
SL.fig3_quant_stats;

clear
powerName = '2.5V';
SL.fig3_rate_stats;


%% Figure 4

clear
SL.fig4_unit_quality;

clear
SL.fig4_recording_sites;

clear
SL.fig4_examples;

clear
SL.fig4_nnmf;

clear
SL.fig4_firing_consistency;

clear
SL.fig4_unit_depth;

clear
SL.fig4_tiling;

clear
SL.fig4_oscillation;


%% Figure 5

% Part 1: coding of behavioral variables
clear
analysisName = 'fig5_seq_coding';
SL.ephys_make_seTb;

clear
analysisName = 'fig5_t_lag';
SL.ephys_make_seTb;

clear
analysisName = 'fig5_seq_coding';
SL.ephys_fit_lm;

clear
analysisName = 'fig5_seq_coding';
SL.ephys_decode;

clear
SL.fig5_t_lag;

clear
SL.fig5_examples;

clear
figName = 'Fig5';
SL.fig5_stimuli;
SL.fig5_projections;

clear
SL.fig5_stats;
SL.fig5_state_space;

% Part 2: coding of surprise signal
clear
SL.fig5_classify;


%% Figure 6

clear
analysisName = 'fig6_iti_coding';
SL.ephys_make_seTb;

clear
analysisName = 'fig6_iti_coding';
SL.ephys_fit_lm;

clear
analysisName = 'fig6_iti_coding';
SL.ephys_decode;

clear
analysisName = 'fig6_seq_coding';
SL.ephys_decode;

clear
SL.fig6_example;

clear
SL.fig6_behav_stats;

clear
SL.fig6_projections;

clear
SL.fig6_lm_stats;


%% Figure 7

clear
analysisName = 'fig7_cons_coding';
SL.ephys_make_seTb;

clear
analysisName = 'fig7_cons_coding';
SL.ephys_decode;

clear
SL.fig7_examples;

clear
SL.fig7_lick_profiles;

clear
SL.fig7_projections;

clear
SL.fig7_distance;


%% Figure Z

clear
SL.figZ_example_trials;

clear
SL.ZZ.MakeSeTable();

clear
analysisName = 'figZ_seq_coding';
SL.ephys_fit_lm;

clear
analysisName = 'figZ_seq_coding';
SL.ephys_decode;

clear
figName = 'FigZ';
SL.fig5_stimuli;
SL.fig5_projections;

clear
predType = 'pca';
SL.figZ_classify;

clear
predType = 'stim';
SL.figZ_classify;

clear
SL.figZ_seq_id_coding;

% SL.ZZ.ReviewShiftMatching();
% SL.ZZ.ReviewUnits();
% SL.ZZ.ReviewCla();


%% Animal Table

% Make animal source table
analysisList = { ...
    'fig1_seq_stats',           'Ext. Fig. 1f-h'; ...
    'fig1_earplug',             'Ext. Fig. 1i'; ...
    'fig1_air',                 'Ext. Fig. 1j'; ...
    'fig1_numbing',             'Ext. Fig. 1k'; ...
    'fig1_learning',            'Ext. Fig. 1l,m'; ...
    'fig3_efficiency',          'Ext. Fig. 3c-f'; ...
    'fig3_extract_data_5V',     'Fig. 2b,c, Ext. Fig. 3j,k'; ...
    'fig3_extract_data_2.5V',   'Ext. Fig. 3l,m'; ...
    'fig4_unit_quality',        'Ext. Fig. 4a-e'; ...
    'fig4_recording_sites',     'Fig. 2d'; ...
    'fig4_nnmf',                'Fig. 2e-h, Ext. Fig. 4i-o'; ...
    'fig5_seq_coding',          'Fig. 3, Ext. Fig. 5a,b,e-g'; ...
    'figZ_seq_coding',          'Fig. 4g, Ext. Fig. 5h'; ...
    'fig7_cons_coding',         'Ext. Fig. 6b-e'; ...
    'fig6_behav_stats',         'Ext. Fig. 7b'; ...
    'fig6_iti_coding',          'Ext. Fig. 7e-g'; ...
    };
% Need to manually add for
% 'Ext. Fig. 2a,b' from a subset of 'fig1_learning' data
% 'Ext. Fig. 2c-e' from a subset of 'fig1_seq_stats' data

aTb = SL.Data.AnimalTable(analysisList{:,1});

% Add example figures
exampleList = { ...
    'MX180203', 'Fig. 1c,d, Ext. Fig. 1e'; ...
    'MX180804', 'Fig. 1g, Ext. Fig. 3h'; ...
    'MX180803', 'Ext. Fig. 3g,i'; ...
    'MX181002', 'Ext. Fig. 4f,5c'; ...
    'MX181302', 'Ext. Fig. 4g'; ...
    'MX170903', 'Ext. Fig. 1n,4h,5d,6a,7a,c,d'; ...
    'MX200101', 'Fig. 4b'; ...
    'MX210301', 'Fig. 4c-f'; ...
    };
isExample = ismember(aTb.animalId, exampleList(:,1));
aTb.examples(isExample) = replace(aTb.animalId(isExample), exampleList(:,1), exampleList(:,2));

SL.Data.SaveTableAsExcel('data source.xlsx', aTb, analysisList');

