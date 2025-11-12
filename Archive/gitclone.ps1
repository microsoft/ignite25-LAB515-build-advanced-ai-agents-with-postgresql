start-job -name gitClone -ScriptBlock {git clone "https://github.com/jjfrost/pg-af-agents-lab" 'C:\Lab2\'}
wait-job -name gitClone 