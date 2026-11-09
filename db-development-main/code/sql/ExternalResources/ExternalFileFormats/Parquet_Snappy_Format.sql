CREATE EXTERNAL FILE FORMAT [Parquet_Snappy_Format]
WITH (
	FORMAT_TYPE = PARQUET,
	DATA_COMPRESSION = 'org.apache.hadoop.io.compress.SnappyCodec'
)
GO
