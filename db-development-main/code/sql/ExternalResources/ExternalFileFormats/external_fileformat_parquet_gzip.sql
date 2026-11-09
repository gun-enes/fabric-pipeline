CREATE EXTERNAL FILE FORMAT [external_fileformat_parquet_gzip]
WITH (
    FORMAT_TYPE = PARQUET,
    DATA_COMPRESSION = 'org.apache.hadoop.io.compress.GzipCodec'
);
GO
