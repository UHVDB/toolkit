process VIRALVERIFY_DOWNLOAD {
    label 'process_single'
    storeDir "${params.db_dir}/viralverify/1.1"
    tag "viralVerify v1.1; db v1.1"

    output:
    path "viralverify_db.hmm"   , emit: viralverify_db
    path ".command.log"         , emit: log
    path ".command.sh"          , emit: script

    script:
    """
    ### Download database
    wget https://figshare.com/ndownloader/files/17904323?private_link=f897d463b31a35ad7bf0

    ### Decompress
    mv 17904323?private_link=f897d463b31a35ad7bf0 viralverify_db.hmm.gz
    gunzip viralverify_db.hmm.gz
    """
}
