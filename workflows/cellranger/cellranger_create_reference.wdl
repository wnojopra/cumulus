workflow cellranger_create_reference {
	String output_dir
	File? input_sample_sheet
	String? input_gtf_file
	String? input_fasta
	String? genome
	String? attributes
	Boolean pre_mrna = false
	String? ref_version

	String? docker_registry = "cumulusprod/"
	String? cellranger_version = '3.1.0'
	Int? disk_space = 100
	Int? preemptible = 2
	String? zones = "us-central1-a us-central1-b us-central1-c us-central1-f us-east1-b us-east1-c us-east1-d us-west1-a us-west1-b us-west1-c"
	Int? num_cpu = 1
	Int? memory = 32

	call generate_create_reference_config {
		input:
			input_sample_sheet = input_sample_sheet,
			input_gtf_file = input_gtf_file,
			input_fasta = input_fasta,
			genome = genome,
			attributes = attributes,
			docker_registry = docker_registry,
			cellranger_version = cellranger_version,
			preemptible = preemptible
	}

	scatter (filt_gtf_row in generate_create_reference_config.filt_gtf_input) {
		call run_filter_gtf {
			input:
				input_gtf_file = filt_gtf_row[0],
				attributes = filt_gtf_row[1],
				pre_mrna = pre_mrna,
				docker_registry = docker_registry,
				cellranger_version = cellranger_version,
				disk_space = disk_space,
				zones = zones,
				memory = memory,
				preemptible = preemptible
		}
	}


	call run_cellranger_mkref {
		input:
			genomes = generate_create_reference_config.genome_names,
			fastas = generate_create_reference_config.fasta_files,
			gtfs = run_filter_gtf.output_gtf_file,
			output_genome = generate_create_reference_config.concated_genome,
			output_dir = output_dir,
			ref_version = ref_version,
			docker_registry = docker_registry,
			cellranger_version = cellranger_version,
			disk_space = disk_space,
			memory = memory,
			num_cpu = num_cpu,
			zones = zones,
			preemptible = preemptible
	}
}



task generate_create_reference_config {
	File? input_sample_sheet
	String? input_gtf_file
	String? input_fasta
	String? genome
	String? attributes

	command {
		set -e
		export TMPDIR=/tmp

		python <<CODE
		import pandas as pd

		if '${input_sample_sheet}' is not '':			
			df = pd.read_csv('${input_sample_sheet}', header = 0, dtype = str, index_col=False)
			for c in df.columns:
				df[c] = df[c].str.strip()
		else:
			df = pd.DataFrame(data = {'Genome' : ['${genome}'], 'Fasta': ['${input_fasta}'], 'Genes': ['${input_gtf_file}'], 'Attributes': ['${attributes}']})


		with open('genome_names.txt', 'w') as fo1, open('fasta_files.txt', 'w') as fo2, open('filt_gtf_input.txt', 'w') as fo3:
			new_genome = []
			for _, row in df.iterrows():
				fo1.write(row['Genome'] + '\n')
				fo2.write(row['Fasta'] + '\n')
				fo3.write("{0}\t{1}\n".format(row['Genes'], row['Attributes']))
				new_genome.append(row['Genome'])
			print('_and_'.join(new_genome))
		CODE
	}

	output {
		Array[String] genome_names = read_lines("genome_names.txt")
		Array[String] fasta_files = read_lines("fasta_files.txt")
		Array[Array[String]] filt_gtf_input = read_tsv('filt_gtf_input.tsv')
		concated_genome = read_string(stdout())
	}

	runtime {
		docker: "${docker_registry}cellranger:${cellranger_version}"
		zones: zones
		preemptible: "${preemptible}"
	}
}

task run_filter_gtf {
	File input_gtf_file
	String attributes
	Boolean pre_mrna

	String docker_registry
	String cellranger_version
	Int disk_space
	String zones
	Int memory
	Int preemptible

	command {
		set -e
		export TMPDIR=/tmp
		monitor_script.sh > monitoring.log &

		python <<CODE
		import os
		from subprocess import check_call

		input_gtf_file = '${input_gtf_file}'
		root, ext = os.path.splitext(input_gtf_file)
		if ext == 'gz':
			call_args = ['gunzip', input_gtf_file]
			print(' '.join(call_args))
			check_call(call_args)
			input_gtf_file = root

		root, ext = os.path.splitext(input_gtf_file)
		file_name = os.path.basename(root)

		output_gtf_file = input_gtf_file # in case no filtering		

		if '${attributes}' is not '':
			file_name += '.filt'
			output_gtf_file = file_name + '.gtf'
			call_args = ['cellranger', 'mkgtf', input_gtf_file, output_gtf_file]
			attrs = '${attributes}'.split(';')
			for attr in attrs:
				call_args.append('--attribute={}'.format(attr))
			print(' '.join(call_args))
			check_call(call_args)
			input_gtf_file = output_gtf_file

		if '${pre_mrna}' is 'true':
			file_name += '.pre_mrna'
			output_gtf_file = file_name + '.gtf'
			call_args = ['awk', 'BEGIN{FS="\t"; OFS="\t"} $3 == "transcript"{ $3="exon"; print}', input_gtf_file]
			print(' '.join(call_args) + '> ' + output_gtf_file)
			with open(output_gtf_file, 'w') as fo:
				check_call(call_args, stdout = fo)

		print(output_gtf_file)		
		CODE
	}

	output {
		File output_gtf_file = read_string(stdout())
	}

	runtime {
		docker: "${docker_registry}cellranger:${cellranger_version}"
		zones: zones
		memory: "${memory}G"
		disks: "local-disk ${disk_space} HDD"
		cpu: 1
		preemptible: "${preemptible}"
	}
}

task run_cellranger_mkref {
	Array[String] genomes
	Array[File] fastas
	Array[File] gtfs
	String output_genome
	String output_dir
	String ref_version

	String docker_registry
	String cellranger_version
	Int disk_space
	Int preemptible
	String zones
	Int num_cpu
	Int memory

	command {
		set -e
		export TMPDIR=/tmp
		monitor_script.sh > monitoring.log &

		python <<CODE
		from subprocess import check_call

		call_args = ['cellranger', 'mkref']
		
		genome_list = '${sep="," genomes}'.split(',')
		fasta_list = '${sep=",", fastas}'.split(',')
		gtf_list = '${sep=",", gtfs}'.split(',')
		for genome, fasta, gtf in zip(genome_list, fasta_list, gtf_list):
			call_args.extend(['--genome=' + genome, '--fasta=' + fasta, '--genes=' + gtf])

		call_args.extend(['--nthreads=${num_cpu}', '--memgb=${memory}'])
		if '${ref_version}' is not '':
			call_args.append('--ref-version=${ref_version}')

		print(' '.join(call_args))
		check_call(call_args)
		CODE

		tar -czf ${output_genome}.tar.gz ${output_genome}
		gsutil cp ${output_genome}.tar.gz ${output_dir}
		# mkdir -p ${output_dir}
		# cp ${output_genome}.tar.gz ${output_dir}
	}

	output {
		String output_reference = '${output_dir}/${output_genome}.tar.gz'
		File monitoringLog = 'monitoring.log'
	}

	runtime {
		docker: "${docker_registry}cellranger:${cellranger_version}"
		zones: zones
		memory: "${memory}G"
		disks: "local-disk ${disk_space} HDD"
		cpu: "${num_cpu}"
		preemptible: "${preemptible}"
	}
}
