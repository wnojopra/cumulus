import "https://api.firecloud.org/ga4gh/v1/tools/scCloud:tasks/versions/18/plain-WDL/descriptor" as tasks
# import "../scCloud/scCloud_tasks.wdl" as tasks

workflow scCloud {
	# Input csv-formatted file containing information of each scRNA-Seq run
	File input_count_matrix_csv
	# Google bucket, subdirectory name and results name prefix
	String output_name
	# Reference genome name, can be None if you want scCloud to infer it from data for you
	String genome = ""

	# scCloud version, default to "0.8.0"
	String? sccloud_version = "0.8.0"
	# Google cloud zones, default to "us-east1-d us-west1-a us-west1-b"
	String? zones = "us-east1-d us-west1-a us-west1-b"
	# Number of cpus per scCloud job
	Int? num_cpu = 64
	# Memory size string
	String? memory = "200G"
	# Total disk space
	Int? disk_space = 100
	# Number of preemptible tries 
	Int? preemptible = 2


	String out_name = basename(output_name)



	# for aggregate_matrices

	# Select channels that satisfy all restrictions. Each restriction takes the format of name:value,...,value. Multiple restrictions are separated by ';'
	String? restrictions
	# Specify a comma-separated list of outputted attributes. These attributes should be column names in the csv file
	String? attributes
	# If we have demultiplexed data, turning on this option will make scCloud only include barcodes that are predicted as singlets
	Boolean? select_only_singlets = false
	# Only keep barcodes with at least this number of expressed genes
	Int? minimum_number_of_genes = 100
	# If inputs are dropseq data
	Boolean is_dropseq = false

	# If inputs are dropseq data, this option needs to turn on and provides the reference genome name
	String dropseq_genome = if is_dropseq then genome else ""



	# for cluster

	# If input data are CITE-Seq data
	Boolean? cite_seq = false
	# For CITE-Seq surface protein expression, make all cells with expression > <percentile> to the value at <percentile> to smooth outlier. Set <percentile> to 100.0 to turn this option off. [default: 99.99]
	Float? cite_seq_capping
	# If output cell and gene filtration results as a spreadsheet. [default: true]
	Boolean? output_filtration_results = true
	# If plot filtration results as PDF files. [default: true]
	Boolean? plot_filtration_results = true
	# Figure size for filtration plots. <figsize> is a comma-separated list of two numbers, the width and height of the figure (e.g. 6,4).
	String? plot_filtration_figsize
	# Output seurat-compatible h5ad file. Caution: File size might be large, do not turn this option on for large data sets. [default: false]
	Boolean? output_seurat_compatible
	# If output loom-formatted file [default: false]
	Boolean? output_loom
	# If output parquet-formatted file [default: false]
	Boolean? output_parquet
	# If correct batch effects [default: false]
	Boolean? correct_batch_effect
	# Batch correction assumes the differences in gene expression between channels are due to batch effects. However, in many cases, we know that channels can be partitioned into several groups and each group is biologically different from others. In this case, we will only perform batch correction for channels within each group. This option defines the groups. If <expression> is None, we assume all channels are from one group. Otherwise, groups are defined according to <expression>. <expression> takes the form of either ‘attr’, or ‘attr1+attr2+…+attrn’, or ‘attr=value11,…,value1n_1;value21,…,value2n_2;…;valuem1,…,valuemn_m’. In the first form, ‘attr’ should be an existing sample attribute, and groups are defined by ‘attr’. In the second form, ‘attr1’,…,’attrn’ are n existing sample attributes and groups are defined by the Cartesian product of these n attributes. In the last form, there will be m + 1 groups. A cell belongs to group i (i > 0) if and only if its sample attribute ‘attr’ has a value among valuei1,…,valuein_i. A cell belongs to group 0 if it does not belong to any other groups.
	String? batch_group_by
	# Only keep cells with at least <number> of genes. [default: 500]
	Int? min_genes
	# Only keep cells with less than <number> of genes. [default: 6000]
	Int? max_genes
	# Only keep cells with at least <number> of UMIs. [default: 100]
	Int? min_umis
	# Only keep cells with less than <number> of UMIs. [default: 600000]	
	Int? max_umis
	# Prefix for mitochondrial genes. [default: MT-]
	String? mito_prefix
	# Only keep cells with mitochondrial ratio less than <ratio>. [default: 0.1]
	Float? percent_mito
	# Only use genes that are expressed in at <ratio> * 100 percent of cells to select variable genes. [default: 0.0005]
	Float? gene_percent_cells
	# If input are raw 10x matrix, which include all barcodes, perform a pre-filtration step to keep the data size small. In the pre-filtration step, only keep cells with at least <number> of genes. [default: 100]
	Int? min_genes_on_raw
	# Total counts per cell after normalization. [default: 1e5]
	Float? counts_per_cell_after
	# Random number generator seed. [default: 0]
	Int? random_state
	# Number of PCs. [default: 50]
	Int? nPC
	# Number of diffusion components. [default: 50]
	Int? nDC
	# Power parameter for diffusion-based pseudotime. [default: 0.5]
	Float? diffmap_alpha
	# Number of neighbors used for constructing affinity matrix. [default: 100]
	Int? diffmap_K
	# For the sake of reproducibility, we only run one thread for building kNN indices. Turn on this option will allow multiple threads to be used for index building. However, it will also reduce reproducibility due to the racing between multiple threads. [default: false]
	Boolean? diffmap_full_speed
	# Run louvain clustering algorithm.
	Boolean? run_louvain = true
	# Resolution parameter for the louvain clustering algorithm. [default: 1.3]
	Float? louvain_resolution
	# Run approximated louvain clustering algorithm.
	Boolean? run_approximated_louvain
	# Number of Kmeans tries. [default: 20]
	Int? approx_louvain_ninit
	# Number of clusters for Kmeans initialization. [default: 30]
	Int? approx_louvain_nclusters
	# Resolution parameter for louvain. [default: 1.3]
	Float? approx_louvain_resolution
	# Run multi-core tSNE for visualization.
	Boolean? run_tsne
	# tSNE’s perplexity parameter. [default: 30]
	Float? tsne_perplexity
	# Run FItSNE for visualization.
	Boolean? run_fitsne = true
	# Run umap for visualization.
	Boolean? run_umap
	# Run umap on diffusion components.
	Int? umap_K
	# Umap parameter. [default: 0.1]
	Float? umap_min_dist
	# Umap parameter. [default: 1.0]
	Float? umap_spread
	# Run force-directed layout embedding.
	Boolean? run_fle
	# K neighbors for building graph for FLE. [default: 50]
	Int? fle_K
	# Number of iterations for FLE. [default: 10000]
	Int? fle_n_steps


	# for de_analysis and annotate_cluster

	# If perform de analysis
	Boolean perform_de_analysis = true
	# Specify the cluster labels used for differential expression analysis. [default: louvain_labels]
	String? cluster_labels
	# Control false discovery rate at <alpha>. [default: 0.05]
	Float? alpha
	# Calculate Fisher’s exact test.
	Boolean? fisher = true
	# Calculate Mann-Whitney U test.
	Boolean? mwu
	# Calculate area under curve in ROC curve.
	Boolean? roc = true

	# If also detect markers using LightGBM
	Boolean? find_markers_lightgbm
	# Remove ribosomal genes with either RPL or RPS as prefixes
	Boolean? remove_ribo
	# Only report genes with a feature importance score (in gain) of at least <gain>. [default: 1.0]
	Float? min_gain

	# If also annotate cell types for clusters based on DE results.
	Boolean? annotate_cluster
	# Organism, could either be "human_immune", "mouse_immune", "human_brain", "mouse_brain" or a JSON file describing the markers. [default: human_immune]
	String? organism
	# Minimum cell type score to report a potential cell type. [default: 0.5]
	Float? minimum_report_score


	# for plot

	# Takes the format of "label:attr,label:attr,...,label:attr". If non-empty, generate composition plot for each "label:attr" pair. "label" refers to cluster labels and "attr" refers to sample conditions.
	String? plot_composition
	# Takes the format of "attr,attr,...,attr". If non-empty, plot attr colored tSNEs side by side.
	String? plot_tsne
	# Takes the format of "attr,attr,...,attr". If non-empty, plot attr colored FItSNEs side by side.
	String? plot_fitsne
	# Takes the format of "attr,attr,...,attr". If non-empty, plot attr colored UMAPs side by side.
	String? plot_umap
	# Takes the format of "attr,attr,...,attr". If non-empty, plot attr colored FLEs side by side.
	String? plot_fle
	# Takes the format of "attr,attr,...,attr". If non-empty, generate attr colored 3D interactive plot. The 3 coordinates are the first 3 PCs of all diffusion components.
	String? plot_diffmap
	# Plot cells based on FIt-SNE coordinates estimated from antibody expressions. Takes the format of "attr,attr,...,attr". If non-empty, plot attr colored FIt-SNEs side by side.
	String? plot_citeseq_fitsne


	# for scp_output

	# If generate outputs required by single cell portal.
	Boolean generate_scp_outputs = false
	# Output dense expression matrix instead.
	Boolean output_dense = false



	call tasks.run_scCloud_aggregate_matrices as aggregate_matrices {
		input:
			input_count_matrix_csv = input_count_matrix_csv,
			output_name = out_name,
			restrictions = restrictions,
			attributes = attributes,
			select_only_singlets = select_only_singlets,
			minimum_number_of_genes = minimum_number_of_genes,
			dropseq_genome = dropseq_genome,
			sccloud_version = sccloud_version,
			zones = zones,
			memory = memory,
			disk_space = disk_space,
			preemptible = preemptible
	}

	call tasks.run_scCloud_cluster as cluster {
		input:
			input_10x_file = aggregate_matrices.output_10x_h5,
			output_name = out_name,
			genome = genome,
			cite_seq = cite_seq,
			cite_seq_capping = cite_seq_capping,
			output_filtration_results = output_filtration_results,
			plot_filtration_results = plot_filtration_results,
			plot_filtration_figsize = plot_filtration_figsize,
			output_seurat_compatible = output_seurat_compatible,
			output_loom = output_loom,
			output_parquet = output_parquet,
			correct_batch_effect = correct_batch_effect,
			batch_group_by = batch_group_by,
			min_genes = min_genes,
			max_genes = max_genes,
			min_umis = min_umis,
			max_umis = max_umis,
			mito_prefix = mito_prefix,
			percent_mito = percent_mito,
			gene_percent_cells = gene_percent_cells,
			min_genes_on_raw = min_genes_on_raw,
			counts_per_cell_after = counts_per_cell_after,
			random_state = random_state,
			nPC = nPC,
			nDC = nDC,
			diffmap_alpha = diffmap_alpha,
			diffmap_K = diffmap_K,
			diffmap_full_speed = diffmap_full_speed,
			run_louvain = run_louvain,
			louvain_resolution = louvain_resolution,
			run_approximated_louvain = run_approximated_louvain,
			approx_louvain_ninit = approx_louvain_ninit,
			approx_louvain_nclusters = approx_louvain_nclusters,
			approx_louvain_resolution = approx_louvain_resolution,
			run_tsne = run_tsne,
			tsne_perplexity = tsne_perplexity,
			run_fitsne = run_fitsne,
			run_umap = run_umap,
			umap_K = umap_K,
			umap_min_dist = umap_min_dist,
			umap_spread = umap_spread,
			run_fle = run_fle,
			fle_K = fle_K,
			fle_n_steps = fle_n_steps,
			sccloud_version = sccloud_version,
			zones = zones,			
			num_cpu = num_cpu,
			memory = memory,
			disk_space = disk_space,
			preemptible = preemptible
	}

	if (perform_de_analysis) {
		call tasks.run_scCloud_de_analysis as de_analysis {
			input:
				input_h5ad = cluster.output_h5ad,
				output_name = out_name,
				labels = cluster_labels,
				alpha = alpha,
				fisher = fisher,
				mwu = mwu,
				roc = roc,
				find_markers_lightgbm = find_markers_lightgbm,
				remove_ribo = remove_ribo,
				min_gain = min_gain,
				random_state = random_state,
				annotate_cluster = annotate_cluster,
				organism = organism,
				minimum_report_score = minimum_report_score,
				sccloud_version = sccloud_version,
				zones = zones,				
				num_cpu = num_cpu,
				memory = memory,
				disk_space = disk_space,
				preemptible = preemptible
		}
	}

	if (defined(plot_composition) || defined(plot_tsne) || defined(plot_fitsne) || defined(plot_umap) || defined(plot_fle) || defined(plot_diffmap) || defined(plot_citeseq_fitsne)) {
		call tasks.run_scCloud_plot as plot {
			input:
				input_h5ad = cluster.output_h5ad,
				output_name = out_name,
				plot_composition = plot_composition,
				plot_tsne = plot_tsne,
				plot_fitsne = plot_fitsne,
				plot_umap = plot_umap,
				plot_fle = plot_fle,
				plot_diffmap = plot_diffmap,
				plot_citeseq_fitsne = plot_citeseq_fitsne,
				sccloud_version = sccloud_version,
				zones = zones,
				memory = memory,
				disk_space = disk_space,
				preemptible = preemptible
		}
	}

	if (generate_scp_outputs) {
		call tasks.run_scCloud_scp_output as scp_output {
			input:
				input_h5ad = cluster.output_h5ad,
				output_name = out_name,
				output_dense = output_dense,
				sccloud_version = sccloud_version,
				zones = zones,
				memory = memory,
				disk_space = disk_space,
				preemptible = preemptible				
		}
	}

	call tasks.organize_results {
		input:
			output_name = output_name,
			output_10x_h5 = aggregate_matrices.output_10x_h5,
			output_h5ad = cluster.output_h5ad,
			output_seurat_h5ad = cluster.output_seurat_h5ad,
			output_filt_xlsx = cluster.output_filt_xlsx,
			output_filt_plot = cluster.output_filt_plot,
			output_loom_file = cluster.output_loom_file,
			output_parquet_file = cluster.output_parquet_file,
			output_de_h5ad = de_analysis.output_de_h5ad,
			output_de_xlsx = de_analysis.output_de_xlsx,
			output_markers_xlsx = de_analysis.output_markers_xlsx,
			output_anno_file = de_analysis.output_anno_file,
			output_pdfs = plot.output_pdfs,
			output_htmls = plot.output_htmls,
			output_scp_files = scp_output.output_scp_files,
			sccloud_version = sccloud_version,
			zones = zones,
			disk_space = disk_space,
			preemptible = preemptible
	}

	output {
		File output_10x_h5 = aggregate_matrices.output_10x_h5
		File output_h5ad = cluster.output_h5ad
		Array[File] output_seurat_h5ad = cluster.output_seurat_h5ad
		Array[File] output_filt_xlsx = cluster.output_filt_xlsx
		Array[File] output_filt_plot = cluster.output_filt_plot
		Array[File] output_loom_file = cluster.output_loom_file
		Array[File] output_parquet_file = cluster.output_parquet_file
		File? output_de_h5ad = de_analysis.output_de_h5ad
		File? output_de_xlsx =  de_analysis.output_de_xlsx
		Array[File]? output_markers_xlsx =  de_analysis.output_markers_xlsx
		Array[File]? output_anno_file =  de_analysis.output_anno_file
		Array[File]? output_pdfs = plot.output_pdfs
		Array[File]? output_htmls = plot.output_htmls
		Array[File]? output_scp_files= scp_output.output_scp_files
	}
}
