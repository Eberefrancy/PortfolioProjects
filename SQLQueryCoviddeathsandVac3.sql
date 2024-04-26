
SELECT *
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
ORDER BY 3,2

SELECT *
FROM PortfolioProject..CovidVaccinations
ORDER BY 3,2

--- Changing Data Type.
EXEC sp_help 'dbo.CovidDeaths';

ALTER TABLE dbo.CovidDeaths
ALTER COLUMN [date] DATE;

ALTER TABLE dbo.CovidDeaths
ALTER COLUMN total_cases FLOAT;

ALTER TABLE dbo.CovidDeaths
ALTER COLUMN total_deaths FLOAT;

---Selecting data that I will be using
SELECT location, date, total_cases, new_cases, total_deaths, population_density
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
ORDER BY 1,2

---Finding out the Total cases vs Total deaths
---Showing likelihood of dying if you contract covid in your country
SELECT location, date, total_cases, total_deaths, (total_deaths/total_cases)*100 AS Death_Percentage
FROM PortfolioProject..CovidDeaths
WHERE location like 'Nigeria' AND continent IS NOT NULL
ORDER BY 1,2

--- Total cases VS Population.
SELECT location, date, total_cases, population_density, (total_deaths/population_density)*100 AS PercentPopulationInfected
FROM PortfolioProject..CovidDeaths
WHERE location like 'Nigeria' AND continent IS NOT NULL
ORDER BY 1,2

---Countries with the Highest Infection Rate compared to Population.
SELECT location AS Location, MAX(total_cases) AS HighestInfectionCount, population_density AS Population, MAX((total_cases/population_density))*100 AS PopulationInfectedPercent
FROM PortfolioProject..CovidDeaths
---WHERE location like 'Nigeria'
WHERE continent IS NOT NULL
GROUP BY location, population_density
ORDER BY PopulationInfectedPercent DESC

---Countries with the Highest Death Count per Population
SELECT location AS Location, MAX(total_deaths) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths
WHERE Continent IS NOT NULL
---WHERE location like 'Nigeria'
GROUP BY Location
ORDER BY TotalDeathCount DESC

--- Breaking Things down by Continent

--- Showing Continents with the highest death count per population

SELECT continent AS Continent, MAX(total_deaths) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths
WHERE Continent IS NOT NULL
---WHERE location like 'Nigeria'
GROUP BY Continent
ORDER BY TotalDeathCount DESC

---GLOBAL NUMBERS

--- Divide by zero error encountered. Warning: Null value is eliminated by an aggregate or other SET operation.
--- The above statement is the error I encountered when I used division(/) aggregation. 

---The error, "Divide by zero error encountered" occurs because there are cases where the sum of new_deaths is zero, 
--resulting in a division by zero error when calculating the DeathPercentage.

---To avoid this error, I added a condition to check if the sum of new_deaths is zero before performing the division.
--I used a CASE statement to handle this scenario. And below is the result.

SELECT date,
    SUM(CAST(new_cases AS int)) AS TotalNewCases,
    SUM(CONVERT(int, new_deaths)) AS TotalNewDeaths,
    CASE 
        WHEN SUM(new_deaths) = 0 THEN 0  -- Handling division by zero
        ELSE SUM(new_deaths) * 100.0 / NULLIF(SUM(new_cases), 0)  -- Preventing division by zero
    END AS DeathPercentage
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL 
GROUP BY date
ORDER BY DeathPercentage DESC

--- OVER ALL TOTAL NEW CASES AND TOTAL NEW DEATHS ACROSS THE WORLD

SELECT 
    SUM(CONVERT(int, new_cases)) AS TotalNewCases,
    SUM(CAST(new_deaths AS int)) AS TotalNewDeaths,
    CASE 
        WHEN SUM(new_deaths) = 0 THEN 0  -- Handling division by zero
        ELSE SUM(new_deaths) * 100.0 / NULLIF(SUM(new_cases), 0)  -- Preventing division by zero
    END AS DeathPercentage
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL 
---GROUP BY date
ORDER BY DeathPercentage DESC

--- WORKING ON BOTH COVID DEATHS AND VACCINATIONS TOGETHER

SELECT *
FROM PortfolioProject..CovidDeaths dea
JOIN PortfolioProject..CovidVaccinations vac
 ON dea.location = vac.location
 AND dea.date = vac.date

 --- TOTAL POPULATION VS VACCINATIONS

SELECT dea.continent, dea.location, dea.date, dea.population_density AS Population, vac.new_vaccinations,
SUM(CAST(vac.new_vaccinations as bigint)) ---I used 'bigint' instead of just 'int' because sum of new_vaccinations is 
--larger than the maximum value that can be stored in an 'int'. 
OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
FROM PortfolioProject..CovidDeaths dea
JOIN PortfolioProject..CovidVaccinations vac
 ON dea.location = vac.location
 AND dea.date = vac.date
 WHERE dea.continent IS NOT NULL 
 ORDER BY 2,3 

 ---USING THE MAX NUMBER OF 'ROLLINGPEOPLEVACCINATED' TO DIVIDE BY POPULATION TO KNOW HOW MANY PEOPLE IN A COUNTRY ARE VACCINATED.
 
 --- USING CTE

 WITH PopvsVac (Continent, Location, Date, Population, new_vaccinations, RollingPeopleVaccinated)
 AS
 (
 SELECT dea.continent, dea.location, dea.date, dea.population_density AS Population, vac.new_vaccinations,
SUM(CAST(vac.new_vaccinations as bigint)) 
OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
---(RollingPeopleVaccinated/Population)*100
FROM PortfolioProject..CovidDeaths dea
JOIN PortfolioProject..CovidVaccinations vac
 ON dea.location = vac.location
 AND dea.date = vac.date
 WHERE dea.continent IS NOT NULL 
 ---ORDER BY 2,3 
 )
 SELECT *, (RollingPeopleVaccinated/Population)*100 AS New_RPV
 FROM PopvsVac


 --- CREATING TEMP TABLE
 
 DROP TABLE IF exists #PercentagePopulationVaccinated
 CREATE TABLE #PercentagePopulationVaccinated
 (
 Continent nvarchar (250),
 Location nvarchar (250),
 Date date,
 Population numeric,
 New_vaccinations numeric,
 RollingPeopleVaccinated numeric
 )

INSERT INTO #PercentagePopulationVaccinated
SELECT dea.continent, dea.location, dea.date, dea.population_density AS Population, vac.new_vaccinations,
SUM(CAST(vac.new_vaccinations as bigint)) 
OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
---(RollingPeopleVaccinated/Population)*100
FROM PortfolioProject..CovidDeaths dea
JOIN PortfolioProject..CovidVaccinations vac
 ON dea.location = vac.location
 AND dea.date = vac.date
 ---WHERE dea.continent IS NOT NULL 
 ---ORDER BY 2,3 

 SELECT *, CASE 
WHEN Population = 0 THEN NULL -- Handle division by zero
ELSE (RollingPeopleVaccinated / NULLIF(Population, 0)) * 100 END AS New_RPV
FROM #PercentagePopulationVaccinated


---CREATING VIEW TO STORE DATA FOR LATER VISUALIZATION

DROP VIEW IF exists PercentagePopulationVaccinated;

CREATE VIEW PercentagePopulationVaccinated AS
SELECT dea.continent, dea.location, dea.date, dea.population_density AS Population, vac.new_vaccinations,
SUM(CAST(vac.new_vaccinations as bigint)) 
OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
---(RollingPeopleVaccinated/Population)*100
FROM PortfolioProject..CovidDeaths dea
JOIN PortfolioProject..CovidVaccinations vac
 ON dea.location = vac.location
 AND dea.date = vac.date
WHERE dea.continent IS NOT NULL 
---ORDER BY 2,3 

SELECT * FROM PercentagePopulationVaccinated
WHERE RollingPeopleVaccinated > 5000;


DROP VIEW IF exists TotalDeathCount

CREATE VIEW [TotalDeathCount] AS
SELECT continent AS Continent, MAX(total_deaths) AS TotalDeathCount
FROM PortfolioProject..CovidDeaths
WHERE Continent IS NOT NULL
---WHERE location like 'Nigeria'
GROUP BY Continent
---ORDER BY TotalDeathCount DESC


SELECT * FROM [TotalDeathCount]
WHERE  TotalDeathCount > 5000;




