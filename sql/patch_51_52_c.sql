# patch_51_52_b.sql
#
# title: add variation_annotation and phenotype tables
#
# description:
# Table containing annotation associated with the variation
# such as GWAS

create table variation_annotation (
        variation_annotation_id int(10) unsigned not null auto_increment,
        variation_id int(10) unsigned not null,
        phenotype_id int(10) unsigned not null,
        source_id int(10) unsigned not null,
        study_tyoe set('GWAS'),
        local_stable_id varchar(255),
        primary key (variation_annotation_id),
        key variation_idx(variation_id),
        key phenotype_idx(phenotype_id),
        key source_idx(source_id)
);

create table phenotype (
        phenotype_id int(10) unsigned not null auto_increment,
        name varchar(50),
        description varchar(255),

        primary key (phenotype_id),
        unique key name_idx(name)
);

INSERT INTO meta (species_id, meta_key, meta_value) VALUES (NULL,'patch', 'patch_51_52_c.sql|add variation_annotation/phenotype table');
