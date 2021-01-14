version 1.0

workflow spaceranger_count {
	input {
		# Sample ID
		String sample_id
		# A comma-separated list of input FASTQs directories (gs urls)
		String input_fastqs_directories
		# spaceranger output directory, gs url
		String output_directory

		# A reference genome name or a URL to a tar.gz file
		String genome

		# Target panel CSV for targeted gene expression analysis
		File? target_panel

		# Brightfield tissue H&E image in .jpg or .tiff format.
		File? image
		# Multi-channel, dark-background fluorescence image as either a single, multi-layer .tiff file, or a pre-combined color .tiff or .jpg file.
		File? darkimage
		#A color composite of one or more fluorescence image channels saved as a single-page, single-file color .tiff or .jpg.
		File? colorizedimage
		# Visium slide serial number. Required unless --unknown-slide is passed.
		String? slide
		# Visium capture area identifier. Required unless --unknown-slide is passed. Options for Visium are A1, B1, C1, D1.
		String? area
		# Slide layout file indicating capture spot and fiducial spot positions.
		File? slidefile
		# Use with automatic image alignment to specify that images may not be in canonical orientation with the hourglass in the top left corner of the image. The automatic fiducial alignment will attempt to align any rotation or mirroring of the image.
		Boolean reorient_images = false
		# Alignment file produced by the manual Loupe alignment step. A --image must be supplied in this case.
		File? loupe_alignment

		# If generate bam outputs
		Boolean no_bam = false
		# Perform secondary analysis of the gene-barcode matrix (dimensionality reduction, clustering and visualization). Default: false
		Boolean secondary = false

		# spaceranger version
		String spaceranger_version
		# Which docker registry to use: cumulusprod (default) or quay.io/cumulus
		String docker_registry

		# Google cloud zones, default to "us-central1-b", which is consistent with CromWell's genomics.default-zones attribute
		String zones = "us-central1-b"
		# Number of cpus per spaceranger job
		Int num_cpu = 32
		# Memory string, e.g. 120G
		String memory = "120G"
		# Disk space in GB
		Int disk_space = 500
		# Number of preemptible tries 
		Int preemptible = 2
	}

	File acronym_file = "gs://regev-lab/resources/cellranger/index.tsv"
	# File acronym_file = "index.tsv"
	Map[String, String] acronym2gsurl = read_map(acronym_file)
	# If reference is a url
	Boolean is_url = sub(genome, "^.+\\.(tgz|gz)$", "URL") == "URL"

	File genome_file = (if is_url then genome else acronym2gsurl[genome])

	call run_spaceranger_count {
		input:
			sample_id = sample_id,
			input_fastqs_directories = input_fastqs_directories,
			output_directory = sub(output_directory, "/+$", ""),
			genome_file = genome_file,
			target_panel = target_panel,
			image = image,
			darkimage = darkimage,
			colorizedimage = colorizedimage,
			slide = slide,
			area = area,
			slidefile = slidefile,
			reorient_images = reorient_images,
			loupe_alignment = loupe_alignment,
			no_bam = no_bam,
			secondary = secondary,
			spaceranger_version = spaceranger_version,
			docker_registry = docker_registry,
			zones = zones,
			num_cpu = num_cpu,
			memory = memory,
			disk_space = disk_space,
			preemptible = preemptible
	}

	output {
		String output_count_directory = run_spaceranger_count.output_count_directory
		String output_metrics_summary = run_spaceranger_count.output_metrics_summary
		String output_web_summary = run_spaceranger_count.output_web_summary
		File monitoringLog = run_spaceranger_count.monitoringLog
	}
}

task run_spaceranger_count {
	input {
		String sample_id
		String input_fastqs_directories
		String output_directory
		File genome_file
		File? target_panel
		File? image
		File? darkimage
		File? colorizedimage
		String? slide
		String? area
		File? slidefile
		Boolean reorient_images
		File? loupe_alignment
		Boolean no_bam
		Boolean secondary
		String spaceranger_version
		String docker_registry
		String zones
		Int num_cpu
		String memory
		Int disk_space
		Int preemptible
    }

	command {
		set -e
		export TMPDIR=/tmp
		monitor_script.sh > monitoring.log &
		mkdir -p genome_dir
		tar xf ~{genome_file} -C genome_dir --strip-components 1

		python <<CODE
		import re
		import sys
		from subprocess import check_call

		fastqs = []
		for i, directory in enumerate('~{input_fastqs_directories}'.split(',')):
			directory = re.sub('/+$', '', directory) # remove trailing slashes 
			call_args = ['gsutil', '-q', '-m', 'cp', '-r', directory + '/~{sample_id}', '.']
			# call_args = ['cp', '-r', directory + '/~{sample_id}', '.']
			print(' '.join(call_args))
			check_call(call_args)
			call_args = ['mv', '~{sample_id}', '~{sample_id}_' + str(i)]
			print(' '.join(call_args))
			check_call(call_args)
			fastqs.append('~{sample_id}_' + str(i))
		
		call_args = ['spaceranger', 'count', '--id=results', '--transcriptome=genome_dir', '--fastqs=' + ','.join(fastqs), '--sample=~{sample_id}', '--jobmode=local']
		if '~{target_panel}' is not '':
			call_args.append('--target-panel=~{target_panel}')

		if '~{image}' is not '':
			call_args.append('--image=~{image}')
		elif '~{darkimage}' is not '':
			call_args.append('--darkimage=~{darkimage}')
		elif '~{colorizedimage}' is not '':
			call_args.append('--colorizedimage=~{colorizedimage}')
		else:
			print("Please set one of the following arguments: image, darkimage or colorizedimage!", file = sys.stderr)
			sys.exit(1)

		if ('~{area}' is '') or ('~{slide}' is ''):
			call_args.append('--unknownslide')
		else:
			call_args.extend(['--area=~{area}', '--slide=~{slide}'])
			if '~{slidefile}' is not '':
				call_args.append('--slidefile=~{slidefile}')

		if '~{reorient_images}' is 'true':
			call_args.append('--reorient_images')
		if '~{loupe_alignment}' is not '':
			if '~{image}' is '':
				print("image option must be set if loupe_alignment is set!", file = sys.stderr)
				sys.exit(1)
			call_args.append('--loupe_alignment=~{loupe_alignment}')

		if '~{no_bam}' is 'true':
			assert version.parse('~{spaceranger_version}') >= version.parse('5.0.0')
			call_args.append('--no-bam')
		if '~{secondary}' is not 'true':
			call_args.append('--nosecondary')

		print(' '.join(call_args))
		check_call(call_args)
		CODE

		gsutil -q -m rsync -d -r results/outs ~{output_directory}/~{sample_id}
		# cp -r results/outs ~{output_directory}/~{sample_id}
	}

	output {
		String output_count_directory = "~{output_directory}/~{sample_id}"
		String output_metrics_summary = "~{output_directory}/~{sample_id}/metrics_summary.csv"
		String output_web_summary = "~{output_directory}/~{sample_id}/web_summary.html"
		File monitoringLog = "monitoring.log"
	}

	runtime {
		docker: "~{docker_registry}/spaceranger:~{spaceranger_version}"
		zones: zones
		memory: memory
		bootDiskSizeGb: 12
		disks: "local-disk ~{disk_space} HDD"
		cpu: "~{num_cpu}"
		preemptible: "~{preemptible}"
	}
}