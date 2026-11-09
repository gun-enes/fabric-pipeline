CREATE FUNCTION [mgmt_xtinfra].[InfraValidateCrontabMonth] (@month NVARCHAR(100))
RETURNS BIT
AS
BEGIN
    DECLARE @isValid BIT = 0;

    -- Check if the input is '*'
    IF @month = '*'
        BEGIN
            SET @isValid = 1;
        END
    ELSE
        BEGIN
        -- Split the input by commas
            DECLARE @currentPart NVARCHAR(255);
            DECLARE @pos INT = 1;
            DECLARE @nextPos INT;
            DECLARE @len INT = LEN(@month) + 1;

            WHILE @pos < @len
                BEGIN
                    SET @nextPos = CHARINDEX(',', @month, @pos);
                    IF @nextPos = 0 SET @nextPos = @len;

                    SET @currentPart = SUBSTRING(@month, @pos, @nextPos - @pos);

                    -- Check if the current part is a single number from 1 to 12 or a range
                    IF
                        NOT (
                            @currentPart LIKE '[1-9]'
                            OR @currentPart LIKE '1[0-2]'
                            OR @currentPart LIKE '[1-9]-[1-9]'
                            OR @currentPart LIKE '[1-9]-1[0-2]'
                            OR @currentPart LIKE '1[0-2]-[1-9]'
                            OR @currentPart LIKE '1[0-2]-1[0-2]'
                        )
                        BEGIN
                            RETURN 0;
                        END

                    SET @pos = @nextPos + 1;
                END

            -- If all parts are valid, set the result to 1
            SET @isValid = 1;
        END

    RETURN @isValid;
END
GO
