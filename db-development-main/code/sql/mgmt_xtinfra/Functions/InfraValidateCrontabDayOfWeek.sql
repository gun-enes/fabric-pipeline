CREATE FUNCTION [mgmt_xtinfra].[InfraValidateCrontabDayOfWeek] (@day_of_week NVARCHAR(100))
RETURNS BIT
AS
BEGIN
    DECLARE @isValid BIT = 0;

    -- Check if the input is '*'
    IF @day_of_week = '*'
        BEGIN
            SET @isValid = 1;
        END
    ELSE
        BEGIN
        -- Split the input by commas
            DECLARE @currentPart NVARCHAR(255);
            DECLARE @pos INT = 1;
            DECLARE @nextPos INT;
            DECLARE @len INT = LEN(@day_of_week) + 1;
            DECLARE @rangePart NVARCHAR(255);
            DECLARE @startPart NVARCHAR(255);
            DECLARE @endPart NVARCHAR(255);

            WHILE @pos < @len
                BEGIN
                    SET @nextPos = CHARINDEX(',', @day_of_week, @pos);
                    IF @nextPos = 0 SET @nextPos = @len;

                    SET @currentPart = SUBSTRING(@day_of_week, @pos, @nextPos - @pos);

                    -- Check if the current part is a single number from 0 to 7 or a range
                    IF CHARINDEX('-', @currentPart) = 0
                        BEGIN
                            -- Single number validation
                            IF
                                NOT (
                                    @currentPart LIKE '[0-7]'
                                )
                                BEGIN
                                    RETURN 0;
                                END
                        END
                    ELSE
                        BEGIN
                            -- Range validation
                            SET @rangePart = @currentPart;
                            SET @startPart = LEFT(@rangePart, CHARINDEX('-', @rangePart) - 1);
                            SET @endPart = RIGHT(@rangePart, LEN(@rangePart) - CHARINDEX('-', @rangePart));

                            IF
                                NOT (
                                    (@startPart LIKE '[0-7]')
                                    AND (@endPart LIKE '[0-7]')
                                )
                                BEGIN
                                    RETURN 0;
                                END
                        END

                    SET @pos = @nextPos + 1;
                END

            -- If all parts are valid, set the result to 1
            SET @isValid = 1;
        END

    RETURN @isValid;
END
GO
