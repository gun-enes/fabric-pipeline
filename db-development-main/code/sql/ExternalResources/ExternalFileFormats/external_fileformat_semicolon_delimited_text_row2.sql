CREATE EXTERNAL FILE FORMAT [external_fileformat_semicolon_delimited_text_row2]
WITH (
    FORMAT_TYPE = DELIMITEDTEXT,
    FORMAT_OPTIONS (
        FIELD_TERMINATOR = ';',
        FIRST_ROW = 2,
        USE_TYPE_DEFAULT = FALSE
    )
);
GO
