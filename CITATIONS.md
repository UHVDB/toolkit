# UHVDB/toolkit: Citations

## Pipeline Tools

If you use UHVDB/toolkit for your analysis, please cite the tools and databases used in your run:

### Read preprocessing

- **fastp** - Chen S, Zhou Y, Chen Y, Gu J. (2018) fastp: an ultra-fast all-in-one FASTQ preprocessor. Bioinformatics, 34(17):i884-i890. doi: [10.1093/bioinformatics/bty560](https://doi.org/10.1093/bioinformatics/bty560)

- **deacon** - Constantinides B, Lees J, Crook DW. (2025) Deacon: fast sequence filtering and contaminant depletion. bioRxiv. doi: [10.1101/2025.06.09.658732](https://doi.org/10.1101/2025.06.09.658732)

### Assembly

- **MEGAHIT** - Li D, Liu CM, Luo R, Sadakane K, Lam TW. (2015) MEGAHIT: an ultra-fast single-node solution for large and complex metagenomics assembly via succinct de Bruijn graph. Bioinformatics, 31(10):1674-6. doi: [10.1093/bioinformatics/btv033](https://doi.org/10.1093/bioinformatics/btv033)

- **seqkit** - Shen W, Le S, Li Y, Hu F. (2016) SeqKit: A Cross-Platform and Ultrafast Toolkit for FASTA/Q File Manipulation. PLoS ONE, 11(10):e0163962. doi: [10.1371/journal.pone.0163962](https://doi.org/10.1371/journal.pone.0163962)

### Virus Classification + Filtering

- **geNomad** - Camargo AP, Nayfach S, Chen IMA, Palaniappan K, Ratner A, Chu K, et al. (2023) Identification of mobile genetic elements with geNomad. Nature Biotechnology. doi: [10.1038/s41587-023-01953-y](https://doi.org/10.1038/s41587-023-01953-y)

- **CheckV** - Nayfach S, Camargo AP, Schulz F, Eloe-Fadrosh E, Roux S, Kyrpides NC. (2021) CheckV assesses the quality and completeness of metagenome-assembled viral genomes. Nature Biotechnology, 39(5):578-585. doi: [10.1038/s41587-020-00774-7](https://doi.org/10.1038/s41587-020-00774-7)

- **viralVerify** - Antipov D, Raiko M, Lapidus A, Pevzner PA. (2020) Metaviral SPAdes: assembly of viruses from metagenomic data. Bioinformatics, 36(14):4126-4129. doi: [10.1093/bioinformatics/btaa490](https://doi.org/10.1093/bioinformatics/btaa490) (ABLAB viral metagenomics tooling; contig verification: [https://github.com/ablab/viralVerify](https://github.com/ablab/viralVerify))

- **csvtk** - Shen W. csvtk: a cross-platform, efficient and practical CSV/TSV toolkit. Available at: [https://github.com/shenwei356/csvtk](https://github.com/shenwei356/csvtk). Versioned releases: [Zenodo](https://zenodo.org/records/4159574).

- **polars** - Polars contributors. Polars: fast multi-threaded DataFrame library. Available at: [https://www.pola.rs](https://www.pola.rs)

- **UHGV** - Camargo AP, Baltoumas FA, Ndela EO, Fiamenghi MB, Merrill BD, Carter MM, Pinto Y, Chakraborty M, Andreeva A, Ghiotto G, Shaw J, Proal AD, Sonnenburg JL, Bhatt AS, Roux S, Pavlopoulos GA, Nayfach S, Kyrpides NC. (2025) A genomic atlas of the human gut virome elucidates genetic factors shaping host interactions. bioRxiv. doi: [10.1101/2025.11.01.686033](https://doi.org/10.1101/2025.11.01.686033)

- **HMMER** - Eddy SR. (2011) Accelerated Profile HMM Searches. PLoS Computational Biology, 7(10):e1002195. doi: [10.1371/journal.pcbi.1002195](https://doi.org/10.1371/journal.pcbi.1002195)

### Clustering and Dereplication

- **tr-trimmer** - Camargo AP. tr-trimmer: identify and trim terminal repeats in viral sequences. Available at: [https://github.com/apcamargo/tr-trimmer](https://github.com/apcamargo/tr-trimmer)

- **seq-hasher** - Camargo AP. seq-hasher: compute hash digests for DNA sequences in FASTA files. Available at: [https://github.com/apcamargo/seq-hasher](https://github.com/apcamargo/seq-hasher)

- **vClust** - Zielezinski A, Gudys A, Barylski J, Siminski K, Rozwalak P, Dutilh BE, Deorowicz S. (2025) Ultrafast and accurate sequence alignment and clustering of viral genomes. Nature Methods, 22(6):1191-1194. doi: [10.1038/s41592-025-02701-7](https://doi.org/10.1038/s41592-025-02701-7)

- **MCL** - Enright AJ, Van Dongen S, Ouzounis CA. (2002) An efficient algorithm for large-scale detection of protein families. Nucleic Acids Research, 30(7):1575-1584. doi: [10.1093/nar/30.7.1575](https://doi.org/10.1093/nar/30.7.1575)

### Virus Taxonomy

- **DIAMOND** - Buchfink B, Xie C, Huson DH. (2015) Fast and sensitive protein alignment using DIAMOND. Nature Methods, 12:59-60. doi: [10.1038/nmeth.3176](https://doi.org/10.1038/nmeth.3176)

- **ICTV** - Simmonds P, Adriaenssens EM, Lefkowitz EJ, Oksanen HM, Siddell SG, Zerbini FM, et al. (2024) Changes to virus taxonomy and the ICTV Statutes ratified by the International Committee on Taxonomy of Viruses (2024). Archives of Virology, 169(11):236. doi: [10.1007/s00705-024-06143-y](https://doi.org/10.1007/s00705-024-06143-y). Taxonomy releases: [https://ictv.global](https://ictv.global)

### Virus Host

- **SpacerExtractor** - Roux S, Neri U, Bushnell B, Fremin B, George NA, Gophna U, Hug LA, Camargo AP, Wu D, Ivanova N, Kyrpides N, Eloe-Fadrosh EE. (2025) Planetary-scale metagenomic search reveals new patterns of CRISPR targeting. bioRxiv. doi: [10.1101/2025.06.12.659409](https://doi.org/10.1101/2025.06.12.659409). Tool: [https://code.jgi.doe.gov/SRoux/spacerextractor](https://code.jgi.doe.gov/SRoux/spacerextractor)

- **VIRE** - Nishijima S, Fullam A, Schmidt TSB, Kuhn M, Bork P. (2025) VIRE: a metagenome-derived, planetary-scale virome resource with environmental context. Nucleic Acids Research, 54(D1):D902-D911. doi: [10.1093/nar/gkaf1225](https://doi.org/10.1093/nar/gkaf1225)

- **PHIST** - Zielezinski A, Deorowicz S, Gudys A. (2022) PHIST: fast and accurate prediction of prokaryotic hosts from metagenomic viral sequences. Bioinformatics, 38(5):1447-1449. doi: [10.1093/bioinformatics/btab837](https://doi.org/10.1093/bioinformatics/btab837)

- **mOTUs-DB** - Milanese A, Mende DR, Paoli L, Salazar G, Ruscheweyh H-J, Cuender SV, et al. (2019) Microbial abundance, activity and population genomic profiling with mOTUs2. Nature Communications, 10:1014. doi: [10.1038/s41467-019-08844-4](https://doi.org/10.1038/s41467-019-08844-4). Database: [https://motus-db.org](https://motus-db.org)

### Virus Function

- **Bakta** - Schwengers O, Jelonek L, Dieckmann MA, Beyvers S, Blom J, Goesmann A. (2021) Bakta: rapid and standardized annotation of bacterial genomes via alignment-free sequence identification. Microbial Genomics, 7(11):000685. doi: [10.1099/mgen.0.000685](https://doi.org/10.1099/mgen.0.000685)

- **Pharokka** - Bouras G, Nepal R, Houtak G, Psaltis AJ, Wormald PJ, Vreugde S. (2023) Pharokka: a fast scalable bacteriophage annotation tool. Bioinformatics, 39(1):btac776. doi: [10.1093/bioinformatics/btac776](https://doi.org/10.1093/bioinformatics/btac776)

- **Phold** - Bouras G, Grigson SR, Mirdita M, Heinzinger M, Papudeshi B, Mallawaarachchi V, Green R, Kim RS, Mihalia V, Psaltis AJ, Wormald PJ, Vreugde S, Steinegger M, Edwards RA. (2026) Protein structure-informed bacteriophage genome annotation with Phold. Nucleic Acids Research, 54(1):gkaf1448. doi: [10.1093/nar/gkaf1448](https://doi.org/10.1093/nar/gkaf1448)

- **foldseek** - van Kempen M, Kim SS, Tumescheit C, Mirdita M, Lee J, Gilchrist CLM, Söding J, Steinegger M. (2024) Fast and accurate protein structure search with Foldseek. Nature Biotechnology, 42:243-246. doi: [10.1038/s41587-023-01773-0](https://doi.org/10.1038/s41587-023-01773-0)

- **Empathi** - Boulay A, Leprince A, Enault F, Rousseau E, Galiez C. (2025) Empathi: embedding-based phage protein annotation tool by hierarchical assignment. Nature Communications, 16:9114. doi: [10.1038/s41467-025-64177-5](https://doi.org/10.1038/s41467-025-64177-5)

### Virus lifestyle

- **BACPHLIP** - Hockenberry AJ, Wilke CO. (2022) BACPHLIP: predicting bacteriophage lifestyle from conserved protein domains. PeerJ, 10:e11396. doi: [10.7717/peerj.11396](https://doi.org/10.7717/peerj.11396)

### Virome analysis

- **sylph** - Shaw J, Yu YW. (2025) Rapid species-level metagenome profiling and containment estimation with sylph. Nature Biotechnology, 43:1348-1359. doi: [10.1038/s41587-024-02412-y](https://doi.org/10.1038/s41587-024-02412-y)

- **CoverM** - Woodcroft BJ. (2022) CoverM: Read coverage calculator for metagenomics. Available at: [https://github.com/wwood/CoverM](https://github.com/wwood/CoverM)

- **scikit-learn** - Pedregosa F, Varoquaux G, Gramfort A, Michel V, Thirion B, Grisel O, Blondel M, Prettenhofer P, Weiss R, Dubourg V, Vanderplas J, Passos A, Cournapeau D, Brucher M, Perrot M, Duchesnay E. (2011) Scikit-learn: Machine Learning in Python. Journal of Machine Learning Research, 12:2825-2830. Available at: [https://www.jmlr.org/papers/v12/pedregosa11a.html](https://www.jmlr.org/papers/v12/pedregosa11a.html)


### Workflow Management

- **Nextflow** - Di Tommaso P, Chatzou M, Floden EW, Barja PP, Palumbo E, Notredame C. (2017) Nextflow enables reproducible computational workflows. Nature Biotechnology, 35(4):316-319. doi: [10.1038/nbt.3820](https://doi.org/10.1038/nbt.3820)

### Software

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/master/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
