create table mgmt_xtinfra.DistributionAdvisorSelectedQueries(
command nvarchar(4000) COLLATE LATIN1_GENERAL_100_CI_AS_SC_UTF8,
tot_te bigint)
with(clustered columnstore index, distribution = ROUND_ROBIN
);
GO
